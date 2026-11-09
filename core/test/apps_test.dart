import 'package:test/test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

void main() {
  group('AppEntry', () {
    test('toJson and fromJson round-trip', () {
      const a = AppEntry(id: 'netflix', name: 'Netflix', package: 'com.netflix.ninja', say: ['netflix']);
      final back = AppEntry.fromJson(a.toJson());
      expect(back.id, 'netflix');
      expect(back.name, 'Netflix');
      expect(back.package, 'com.netflix.ninja');
      expect(back.say, ['netflix']);
    });

    test('custom: own name is always spoken, extras are added once, empties dropped', () {
      final a = AppEntry.custom(name: 'Plex', package: 'com.plexapp.android', extraSay: ['plex media', ' PLEX ', '', '   ']);
      expect(a.id, 'plex');
      expect(a.say, ['Plex', 'plex media']);
    });

    test('custom: id is unique among the taken ids', () {
      final a = AppEntry.custom(name: 'Plex', package: 'com.plexapp.android', takenIds: ['plex', 'plex2']);
      expect(a.id, 'plex3');
    });

    test('custom: a name with no Latin letters gets an id from the package and no spoken name', () {
      final a = AppEntry.custom(name: 'हॉटस्टार', package: 'in.startv.hotstar');
      expect(a.id, 'hotstar');
      expect(a.say, isEmpty);
      final b = AppEntry.custom(name: 'हॉटस्टार', package: 'in.startv.hotstar', extraSay: ['hotstar']);
      expect(b.say, ['hotstar']);
    });

    test('copyWith keeps the id', () {
      const a = AppEntry(id: 'x', name: 'X', package: 'com.x.app', say: ['x']);
      final b = a.copyWith(name: 'Y');
      expect(b.id, 'x');
      expect(b.name, 'Y');
      expect(b.package, 'com.x.app');
    });
  });

  group('isValidPackage', () {
    test('accepts real application ids', () {
      for (final p in ['com.netflix.ninja', 'in.startv.hotstar', 'tv.twitch.android.app', 'org.xbmc.kodi', 'com.my_app.v2']) {
        expect(isValidPackage(p), isTrue, reason: p);
      }
    });
    test('rejects things that are not application ids', () {
      for (final p in ['', 'netflix', 'com.', '.com.x', 'com..x', 'com.1x.app', 'com.net flix.app', 'https://x.com/app', 'com.x.app?id=1']) {
        expect(isValidPackage(p), isFalse, reason: p);
      }
    });
  });

  group('names', () {
    const apps = [
      AppEntry(id: 'netflix', name: 'Netflix', package: 'com.netflix.ninja', say: ['netflix']),
      AppEntry(id: 'prime', name: 'Prime Video', package: 'com.amazon.amazonvideo.livingroom', say: ['prime video', 'prime']),
    ];

    test('appUsingName finds the app that already answers to a name, ignoring case, punctuation and filler', () {
      expect(appUsingName(apps, 'NETFLIX')?.id, 'netflix');
      expect(appUsingName(apps, 'The Prime!')?.id, 'prime');
      expect(appUsingName(apps, 'plex'), isNull);
      expect(appUsingName(apps, ''), isNull);
    });

    test('appUsingName can skip the app being edited', () {
      expect(appUsingName(apps, 'netflix', exceptId: 'netflix'), isNull);
    });

    test('isReserved flags words that already mean a TV command', () {
      for (final w in ['home', 'Back', 'pause', 'mute', 'volume', 'open', 'ok', 'standby']) {
        expect(PhraseParser.isReserved(w), isTrue, reason: w);
      }
      expect(PhraseParser.isReserved('plex'), isFalse);
    });
  });

  group('parser with a user-edited list', () {
    test('opens a custom app by its own name and by an extra name', () {
      final plex = AppEntry.custom(name: 'Plex', package: 'com.plexapp.android', extraSay: ['plex media']);
      final p = PhraseParser([plex]);
      expect(p.parse('open plex'), isA<OpenApp>().having((a) => a.id, 'id', 'plex'));
      expect(p.parse('launch plex media'), isA<OpenApp>().having((a) => a.id, 'id', 'plex'));
      expect(p.parse('open netflix'), isA<Unknown>());
    });

    test('an app with no spoken name never matches the empty phrase', () {
      final silent = AppEntry.custom(name: 'हॉटस्टार', package: 'in.startv.hotstar');
      final p = PhraseParser([silent]);
      expect(p.parse(''), isA<Unknown>());
      expect(p.parse('open'), isA<Unknown>());
    });

    test('an empty list parses commands but opens nothing', () {
      final p = PhraseParser(const []);
      expect(p.parse('open netflix'), isA<Unknown>());
      expect(p.parse('volume 30'), isA<VolumeSet>());
    });
  });
}
