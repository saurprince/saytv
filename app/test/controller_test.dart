import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';
import 'package:tv_voice_remote/controller.dart';
import 'package:tv_voice_remote/store.dart';

/// Every read fails, like a damaged secure-storage entry or a missing asset.
class _BrokenStore extends Store {
  @override
  Future<Identity?> loadIdentity() async => throw StateError('cannot decrypt');
  @override
  Future<String?> loadHost() async => '192.168.1.5';
  @override
  Future<String?> loadTvName() async => throw StateError('broken');
  @override
  Future<List<AppEntry>> loadApps() async => throw StateError('Unable to load asset');
  @override
  Future<List<AppEntry>> loadCatalog() async => throw StateError('Unable to load asset');
}

/// Reads fine, nothing stored yet (a first start).
class _EmptyStore extends Store {
  @override
  Future<Identity?> loadIdentity() async => null;
  @override
  Future<String?> loadHost() async => null;
  @override
  Future<String?> loadTvName() async => null;
  @override
  Future<List<AppEntry>> loadApps() async => const [
        AppEntry(id: 'netflix', name: 'Netflix', package: 'com.netflix.ninja', say: ['netflix']),
      ];
  @override
  Future<List<AppEntry>> loadCatalog() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('init finishes, unpaired, when the stored data cannot be read (no endless spinner)', () async {
    final c = TvController(_BrokenStore());
    await c.init();
    expect(c.ready, isTrue);
    expect(c.paired, isFalse); // the identity is unreadable, so the app goes to the pairing screen
    expect(c.apps, isEmpty);
    expect(c.catalog, isEmpty);
    expect(c.displayName, 'your TV');
    c.dispose();
  });

  test('first start: ready, unpaired, the default app list is used', () async {
    final c = TvController(_EmptyStore());
    await c.init();
    expect(c.ready, isTrue);
    expect(c.paired, isFalse);
    expect(c.apps.map((a) => a.id), ['netflix']);
    expect(c.parser.parse('open netflix'), isA<OpenApp>());
    c.dispose();
  });

  test('the TV is called by the name the user gave it, else the model, else "your TV"', () async {
    final c = TvController(_EmptyStore());
    await c.init();
    expect(c.displayName, 'your TV');
    c.tvName = 'Living room';
    expect(c.displayName, 'Living room');
    c.dispose();
  });
}
