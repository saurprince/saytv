import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

/// A TV found on the network.
class FoundTv {
  const FoundTv(this.host, {this.name});
  final String host;
  final String? name;
  @override
  String toString() => name == null ? host : '$name ($host)';
}

const _service = '_androidtvremote2._tcp.local';

/// Looks for TVs announcing the remote service (mDNS / Bonjour).
/// On the tested TV a plain multicast query got no answer from a Windows PC, so use [scanSubnet] as the fallback.
Future<List<FoundTv>> discoverMdns({Duration timeout = const Duration(seconds: 5)}) async {
  final client = MDnsClient();
  final found = <String, FoundTv>{};
  try {
    await client.start();
    await for (final ptr in client
        .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_service), timeout: timeout)) {
      await for (final srv in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName),
          timeout: const Duration(seconds: 2))) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target),
            timeout: const Duration(seconds: 2))) {
          found[ip.address.address] = FoundTv(ip.address.address, name: ptr.domainName.split('.').first);
        }
      }
    }
  } catch (_) {
    // no network permission or no answer: the caller falls back to a scan
  } finally {
    client.stop();
  }
  return found.values.toList();
}

/// True for the address ranges used inside a home or office network (10.x, 172.16-31.x, 192.168.x).
/// Cellular and other public addresses are left out: a TV is never there, and scanning them only wastes time.
bool isPrivateIPv4(String address) {
  final p = address.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((n) => n == null)) return false;
  final a = p[0]!, b = p[1]!;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

/// The first three parts of each private IPv4 address the phone has on its networks, e.g. `192.168.1`.
/// Wi-Fi and Ethernet first (iPhone en0, Android wlan0, Windows "Wi-Fi" / "Ethernet"), virtual and cellular ones after.
Future<Set<String>> localPrefixes() async {
  int rank(String name) {
    final n = name.toLowerCase();
    return (n.startsWith('en') && !n.startsWith('en-') || n.startsWith('wlan') || n.startsWith('eth') || n == 'wi-fi' || n.startsWith('wi-fi')) ? 0 : 1;
  }

  final nics = (await NetworkInterface.list(type: InternetAddressType.IPv4)).toList()
    ..sort((a, b) => rank(a.name).compareTo(rank(b.name)));
  final prefixes = <String>{}; // a Set keeps the order it was filled in
  for (final nic in nics) {
    for (final addr in nic.addresses) {
      if (addr.isLoopback || addr.isLinkLocal || !isPrivateIPv4(addr.address)) continue;
      prefixes.add(addr.address.split('.').take(3).join('.'));
    }
  }
  return prefixes;
}

/// Runs [probe] on every host, at most [maxParallel] at a time, and returns the hosts it said yes to.
/// An iPhone app may have only about 256 files open (every socket is one), so opening 254 sockets at once makes some fail at random.
Future<List<String>> probeHosts(List<String> hosts, Future<bool> Function(String host) probe, {int maxParallel = 64}) async {
  final found = <String>[];
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= hosts.length) return;
      if (await probe(hosts[i])) found.add(hosts[i]);
    }
  }

  await Future.wait(List.generate(maxParallel < 1 ? 1 : maxParallel, (_) => worker()));
  return found;
}

/// Tries port 6466 on every address of the phone's own /24 networks, 64 at a time. Takes a few seconds.
/// The timeout is generous: the first packets to a Wi-Fi device can be slow while the network learns its address.
Future<List<FoundTv>> scanSubnet({Duration connectTimeout = const Duration(milliseconds: 1200)}) async {
  final found = <FoundTv>[];
  for (final prefix in await localPrefixes()) {
    final hosts = [for (var i = 1; i < 255; i++) '$prefix.$i'];
    final open = await probeHosts(hosts, (host) async {
      try {
        final s = await Socket.connect(host, 6466, timeout: connectTimeout);
        s.destroy();
        return true;
      } catch (_) {
        return false;
      }
    });
    open.sort((a, b) => int.parse(a.split('.').last).compareTo(int.parse(b.split('.').last)));
    found.addAll(open.map((h) => FoundTv(h)));
    if (found.isNotEmpty) break; // found on this network: no need to search the others
  }
  return found;
}
