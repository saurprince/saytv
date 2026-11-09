import 'dart:async';

import 'package:test/test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

void main() {
  test('probeHosts never has more than maxParallel probes running, and finds the right hosts', () async {
    // On iPhone every socket is an open file and the app may have only about 256, so the scan must not open 254 at once.
    final hosts = [for (var i = 1; i < 255; i++) '192.168.1.$i'];
    var running = 0;
    var most = 0;
    final open = await probeHosts(hosts, (host) async {
      running++;
      if (running > most) most = running;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      running--;
      return host == '192.168.1.12' || host == '192.168.1.200';
    }, maxParallel: 64);
    expect(most, lessThanOrEqualTo(64));
    expect(most, greaterThan(1)); // still parallel, not one by one
    expect(open..sort(), ['192.168.1.12', '192.168.1.200']);
  });

  test('probeHosts probes every host exactly once, also when there are fewer hosts than workers', () async {
    final seen = <String>[];
    final open = await probeHosts(['a', 'b', 'c'], (h) async {
      seen.add(h);
      return true;
    }, maxParallel: 64);
    expect(seen..sort(), ['a', 'b', 'c']);
    expect(open..sort(), ['a', 'b', 'c']);
  });

  test('only home and office address ranges are scanned (not cellular, public or garbage)', () {
    for (final ok in ['192.168.1.19', '192.168.0.5', '10.0.0.7', '172.16.0.1', '172.31.255.1']) {
      expect(isPrivateIPv4(ok), isTrue, reason: ok);
    }
    for (final no in ['100.64.1.2', '8.8.8.8', '172.15.0.1', '172.32.0.1', '192.169.1.1', '169.254.1.1', '1.2.3', 'abc', '']) {
      expect(isPrivateIPv4(no), isFalse, reason: no);
    }
  });

  test('probeHosts with no hosts finds nothing', () async {
    expect(await probeHosts([], (h) async => true), isEmpty);
  });
}
