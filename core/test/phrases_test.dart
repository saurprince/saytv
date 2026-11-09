import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

void main() {
  final apps = [
    for (final a in (jsonDecode(File('../spec/apps.json').readAsStringSync())['apps'] as List))
      AppEntry.fromJson(a as Map<String, dynamic>)
  ];
  final spec = jsonDecode(File('../spec/phrases.json').readAsStringSync()) as Map<String, dynamic>;
  final parser = PhraseParser(apps, volumeStep: (spec['defaults']['volume_step'] as int));

  group('spec/phrases.json', () {
    for (final c in (spec['cases'] as List).cast<Map<String, dynamic>>()) {
      test('"${c['say']}"', () {
        expect(parser.parse(c['say'] as String).toJson(), equals(c['do']));
      });
    }
  });

  test('speech recognizers add capitals and punctuation', () {
    expect(parser.parse('Open Netflix.').toJson(), {'type': 'app', 'id': 'netflix'});
    expect(parser.parse('Please, turn the volume up!').toJson(), {'type': 'volume_delta', 'delta': 5});
    expect(parser.parse('Set the volume to 30 %').toJson(), {'type': 'volume_set', 'level': 30});
  });

  test('numbers spoken as words', () {
    expect(parser.parse('set volume to twenty five').toJson(), {'type': 'volume_set', 'level': 25});
    expect(parser.parse('volume one hundred').toJson(), {'type': 'volume_set', 'level': 100});
    expect(parser.parse('volume up by fifteen').toJson(), {'type': 'volume_delta', 'delta': 15});
  });

  test('a volume above 100 is clamped', () {
    expect(parser.parse('volume 250').toJson(), {'type': 'volume_set', 'level': 100});
  });
}
