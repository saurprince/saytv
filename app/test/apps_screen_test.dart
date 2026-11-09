import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';
import 'package:tv_voice_remote/apps_screen.dart';
import 'package:tv_voice_remote/controller.dart';
import 'package:tv_voice_remote/store.dart';

const netflix = AppEntry(id: 'netflix', name: 'Netflix', package: 'com.netflix.ninja', say: ['netflix']);
const prime = AppEntry(id: 'prime', name: 'Prime Video', package: 'com.amazon.amazonvideo.livingroom', say: ['prime video', 'prime']);
const plex = AppEntry(id: 'plex', name: 'Plex', package: 'com.plexapp.android', say: ['plex']);
const kodi = AppEntry(id: 'kodi', name: 'Kodi', package: 'org.xbmc.kodi', say: ['kodi']);

/// A Store that keeps what is saved in memory, so the tests need no platform storage.
class _FakeStore extends Store {
  List<AppEntry>? saved;
  bool resetCalled = false;

  @override
  Future<void> saveApps(List<AppEntry> apps) async => saved = apps;

  @override
  Future<void> resetApps() async => resetCalled = true;

  @override
  Future<List<AppEntry>> loadDefaultApps() async => const [netflix, prime];
}

void main() {
  late _FakeStore store;
  late TvController c;

  setUp(() {
    store = _FakeStore();
    c = TvController(store)
      ..apps = [netflix, prime]
      ..catalog = [plex, kodi, netflix]
      ..parser = PhraseParser(const [netflix, prime]);
  });

  tearDown(() => c.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AppsScreen(controller: c)));
  }

  Future<void> fillAndSave(WidgetTester tester, {required String name, required String package, String extra = ''}) async {
    await tester.tap(find.text('Add your own app'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('app-name')), name);
    await tester.enterText(find.byKey(const Key('app-package')), package);
    if (extra.isNotEmpty) await tester.enterText(find.byKey(const Key('app-extra')), extra);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the apps and offers only suggestions that are not already there', (tester) async {
    await open(tester);
    expect(find.text('Netflix'), findsOneWidget); // the list row; the suggestion for the same package is hidden
    expect(find.text('Prime Video'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Plex'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Kodi'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Netflix'), findsNothing);
  });

  testWidgets('adding your own app saves it and makes it answer to "open <name>"', (tester) async {
    await open(tester);
    await fillAndSave(tester, name: 'Special Channel', package: 'com.example.special', extra: 'specials, the special one');
    expect(c.apps.map((a) => a.name), ['Netflix', 'Prime Video', 'Special Channel']);
    expect(store.saved!.length, 3);
    expect(c.parser.parse('open special channel'), isA<OpenApp>());
    expect(c.parser.parse('launch specials'), isA<OpenApp>());
    expect(find.text('Special Channel'), findsOneWidget);
  });

  testWidgets('a package name that is not an application id is refused and nothing changes', (tester) async {
    await open(tester);
    await fillAndSave(tester, name: 'Broken', package: 'broken');
    expect(find.textContaining('does not look right'), findsOneWidget);
    expect(c.apps.length, 2);
    expect(store.saved, isNull);
  });

  testWidgets('a name that already opens another app is refused', (tester) async {
    await open(tester);
    await fillAndSave(tester, name: 'Netflix', package: 'com.other.app');
    expect(find.textContaining('already opens Netflix'), findsOneWidget);
    expect(c.apps.length, 2);
  });

  testWidgets('a name that is already a TV command is refused', (tester) async {
    await open(tester);
    await fillAndSave(tester, name: 'Home', package: 'com.other.home');
    expect(find.textContaining('already means a TV command'), findsOneWidget);
    expect(c.apps.length, 2);
  });

  testWidgets('the same package cannot be added twice', (tester) async {
    await open(tester);
    await fillAndSave(tester, name: 'Netflix Two', package: 'com.netflix.ninja');
    expect(find.textContaining('already uses this package'), findsOneWidget);
    expect(c.apps.length, 2);
  });

  testWidgets('tapping a suggestion adds it and removes it from the suggestions', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Plex'));
    await tester.pumpAndSettle();
    expect(c.apps.map((a) => a.id), ['netflix', 'prime', 'plex']);
    expect(find.widgetWithText(ActionChip, 'Plex'), findsNothing);
    expect(c.parser.parse('open plex'), isA<OpenApp>());
  });

  testWidgets('removing an app can be undone, back into the same place', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Remove Netflix'));
    await tester.pumpAndSettle();
    expect(c.apps.map((a) => a.id), ['prime']);
    expect(c.parser.parse('open netflix'), isA<Unknown>());
    expect(find.text('Removed Netflix'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.apps.map((a) => a.id), ['netflix', 'prime']);
  });

  testWidgets('editing keeps the id and updates the spoken names', (tester) async {
    await open(tester);
    await tester.tap(find.text('Prime Video'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('app-name')), 'Amazon Prime');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final edited = c.apps.firstWhere((a) => a.id == 'prime');
    expect(edited.name, 'Amazon Prime');
    expect(edited.package, prime.package);
    expect(c.parser.parse('open amazon prime'), isA<OpenApp>());
    expect(c.parser.parse('open prime'), isA<OpenApp>()); // an old spoken name still works
  });

  testWidgets('restoring the original list asks first', (tester) async {
    await open(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore the original list'));
    await tester.pumpAndSettle();
    expect(find.text('Restore the original list?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(store.resetCalled, isTrue);
  });
}
