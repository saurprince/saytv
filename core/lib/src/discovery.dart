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

/// Tries port 6466 on every address of the phone's own /24 networks. Takes about 3 seconds.
Future<List<FoundTv>> scanSubnet({Duration connectTimeout = const Duration(milliseconds: 700)}) async {
  final found = <FoundTv>[];
  final prefixes = <String>{};
  for (final nic in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final addr in nic.addresses) {
      if (addr.isLoopback || addr.isLinkLocal) continue;
      final parts = addr.address.split('.');
      prefixes.add(parts.take(3).join('.'));
    }
  }
  for (final prefix in prefixes) {
    final tries = <Future<void>>[];
    for (var i = 1; i < 255; i++) {
      final host = '$prefix.$i';
      tries.add(Socket.connect(host, 6466, timeout: connectTimeout).then((s) {
        s.destroy();
        found.add(FoundTv(host));
      }).catchError((Object _) {}));
    }
    await Future.wait(tries);
  }
  return found;
}
