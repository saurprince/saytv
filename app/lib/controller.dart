import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

import 'branding.dart';
import 'store.dart';

enum Link { idle, connecting, connected, unreachable }

/// Owns the one connection to the TV: connects, reconnects, and turns taps and spoken phrases into commands.
class TvController extends ChangeNotifier with WidgetsBindingObserver {
  TvController(this.store);

  final Store store;
  Identity? identity;
  String? host;
  List<AppEntry> apps = [];
  List<AppEntry> catalog = [];
  PhraseParser parser = PhraseParser(const []);
  String? tvName;

  /// What the status line calls the TV: the user's own name, else the model the TV reports, else a plain "your TV".
  String get displayName => (tvName != null && tvName!.isNotEmpty) ? tvName! : (tv.model ?? 'your TV');

  bool ready = false;
  Link link = Link.idle;
  TvState tv = const TvState();
  String? lastHeard;
  String? lastResult;

  RemoteConnection? _conn;
  StreamSubscription<TvState>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _connecting = false;
  bool _disposed = false;

  bool get paired => identity != null && host != null;

  /// One read of what the phone remembers. A read may fail on its own (for example a damaged secure-storage entry after a restore from
  /// backup): the app then starts as if that item was never stored, instead of hanging on the loading spinner.
  Future<T?> _try<T extends Object>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    identity = await _try(store.loadIdentity);
    host = await _try(store.loadHost);
    tvName = await _try(store.loadTvName);
    apps = await _try(store.loadApps) ?? [];
    catalog = await _try(store.loadCatalog) ?? [];
    parser = PhraseParser(apps);
    ready = true;
    notifyListeners();
    if (paired) unawaited(connect());
  }

  // ---- the app list the user can edit ----
  Future<void> setApps(List<AppEntry> list) async {
    apps = List.of(list);
    parser = PhraseParser(apps);
    notifyListeners();
    await store.saveApps(apps);
  }

  /// Adds [app], giving it a fresh id if that one is taken.
  Future<void> addApp(AppEntry app) {
    final ids = apps.map((a) => a.id).toSet();
    var id = app.id;
    for (var i = 2; ids.contains(id); i++) {
      id = '${app.id}$i';
    }
    return setApps([...apps, id == app.id ? app : AppEntry(id: id, name: app.name, package: app.package, say: app.say)]);
  }

  Future<void> resetApps() async {
    await store.resetApps();
    apps = await store.loadDefaultApps();
    parser = PhraseParser(apps);
    notifyListeners();
  }

  Future<void> renameTv(String? name) async {
    tvName = (name == null || name.trim().isEmpty) ? null : name.trim();
    notifyListeners();
    await store.saveTvName(tvName);
  }

  /// Called after a successful pairing.
  Future<void> setPaired(Identity id, String tvHost) async {
    await store.saveIdentity(id);
    await store.saveHost(tvHost);
    identity = id;
    host = tvHost;
    notifyListeners();
    unawaited(connect());
  }

  Future<void> forget() async {
    _disconnect();
    await store.forget();
    identity = null;
    host = null;
    tvName = null;
    link = Link.idle;
    notifyListeners();
  }

  // ---- connection ----
  Future<void> connect() async {
    if (!paired || _connecting || link == Link.connected) return;
    _connecting = true;
    _retry?.cancel();
    link = Link.connecting;
    notifyListeners();
    try {
      final c = await RemoteConnection.connect(host!, identity!, clientName: appName);
      _conn = c;
      tv = c.state;
      link = Link.connected;
      _attempt = 0;
      _sub = c.states.listen((s) {
        tv = s;
        notifyListeners();
      });
      unawaited(c.done.then((_) {
        if (identical(_conn, c)) {
          _conn = null;
          _sub?.cancel();
          link = Link.unreachable;
          notifyListeners();
          _scheduleRetry();
        }
      }));
    } catch (_) {
      link = Link.unreachable;
      _scheduleRetry();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  void _scheduleRetry() {
    if (_disposed || !paired) return;
    _retry?.cancel();
    const delays = [2, 4, 8, 15]; // seconds between reconnect attempts, then every 15 s
    final secs = delays[_attempt < delays.length ? _attempt : delays.length - 1];
    _attempt++;
    _retry = Timer(Duration(seconds: secs), connect);
  }

  void _disconnect() {
    _retry?.cancel();
    _sub?.cancel();
    final c = _conn;
    _conn = null;
    c?.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_conn == null || _conn!.isClosed) {
        link = Link.idle;
        unawaited(connect());
      }
    } else if (state == AppLifecycleState.paused) {
      // The phone suspends sockets in the background anyway; closing cleanly lets the TV free its virtual remote.
      _disconnect();
      link = Link.idle;
    }
  }

  Future<RemoteConnection?> _ready() async {
    if (_conn == null || _conn!.isClosed) {
      link = Link.idle;
      await connect();
    }
    return link == Link.connected ? _conn : null;
  }

  // ---- commands ----
  Future<void> key(int code) async => (await _ready())?.key(code);

  Future<void> setVolume(int level) async => await (await _ready())?.setVolume(level);

  Future<void> volumeBy(int delta) async => await (await _ready())?.volumeBy(delta);

  Future<void> toggleMute() async => await (await _ready())?.setMuted(!tv.muted);

  Future<void> openApp(AppEntry app) async {
    final c = await _ready();
    if (c == null) return;
    await c.wake(); // an app started while the screensaver is showing ends up behind it
    c.launchPackage(app.package);
  }

  /// Spoken or typed phrase -> action. Returns what was understood, for the screen.
  Future<String> say(String phrase) async {
    lastHeard = phrase;
    final action = parser.parse(phrase);
    String result;
    switch (action) {
      case OpenApp(:final id):
        final app = apps.firstWhere((a) => a.id == id);
        await openApp(app);
        result = 'Opening ${app.name}';
      case VolumeDelta(:final delta):
        await volumeBy(delta);
        result = delta > 0 ? 'Volume up' : 'Volume down';
      case VolumeSet(:final level):
        await setVolume(level);
        result = 'Volume $level';
      case MuteAction(:final on):
        final c = await _ready();
        await c?.setMuted(on);
        result = on ? 'Muted' : 'Sound on';
      case PressKey(:final key):
        await this.key(Keys.byName[key]!);
        result = key == 'POWER' ? 'Standby' : key[0] + key.substring(1).toLowerCase().replaceAll('_', ' ');
      case Unknown():
        result = 'Not understood';
    }
    lastResult = link == Link.connected ? result : 'The TV is not reachable';
    notifyListeners();
    return lastResult!;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disconnect();
    super.dispose();
  }
}
