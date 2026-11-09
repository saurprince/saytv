import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in ['apps.json', 'catalog.json']) {
    test('assets/$name is an exact copy of ../spec/$name', () {
      final asset = File('assets/$name').readAsStringSync().replaceAll('\r\n', '\n');
      final spec = File('../spec/$name').readAsStringSync().replaceAll('\r\n', '\n');
      expect(asset, equals(spec));
    });
  }
}
