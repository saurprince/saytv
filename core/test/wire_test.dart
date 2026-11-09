import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tv_remote_core/src/wire.dart';

void main() {
  test('varints round-trip', () {
    for (final n in [0, 1, 127, 128, 300, 16384, 1 << 28]) {
      final f = parseFields(fInt(1, n));
      expect(f.intOf(1), n);
    }
  });

  test('nested messages and strings', () {
    final msg = fBytes(2, concat([fStr(1, 'Test TV'), fInt(3, 7)]));
    final f = parseFields(msg);
    expect(f.subOf(2)!.stringOf(1), 'Test TV');
    expect(f.subOf(2)!.intOf(3), 7);
  });

  test('FrameReader reassembles split and merged frames', () {
    final a = frame(fInt(1, 5));
    final b = frame(fStr(2, 'hello'));
    final all = Uint8List.fromList([...a, ...b]);
    final r = FrameReader();
    r.add(all.sublist(0, 2));
    expect(r.takeFrames(), isEmpty);
    r.add(all.sublist(2, a.length + 3));
    final first = r.takeFrames();
    expect(first.length, 1);
    expect(parseFields(first.first).intOf(1), 5);
    r.add(all.sublist(a.length + 3));
    final second = r.takeFrames();
    expect(second.length, 1);
    expect(parseFields(second.first).stringOf(2), 'hello');
  });
}
