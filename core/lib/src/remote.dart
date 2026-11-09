import 'dart:async';
import 'dart:typed_data';

import 'identity.dart';
import 'keys.dart';
import 'tv_socket.dart';
import 'wire.dart';

/// What the TV last told us about itself.
class TvState {
  const TvState({
    this.model,
    this.volume = 0,
    this.volumeMax = 100,
    this.muted = false,
    this.screenOn = true,
    this.app,
  });

  final String? model;
  final int volume;
  final int volumeMax;
  final bool muted;
  final bool screenOn;
  final String? app;

  TvState copyWith({String? model, int? volume, int? volumeMax, bool? muted, bool? screenOn, String? app}) => TvState(
        model: model ?? this.model,
        volume: volume ?? this.volume,
        volumeMax: volumeMax ?? this.volumeMax,
        muted: muted ?? this.muted,
        screenOn: screenOn ?? this.screenOn,
        app: app ?? this.app,
      );

  @override
  String toString() => 'TvState(model: $model, volume: $volume/$volumeMax, muted: $muted, screenOn: $screenOn, app: $app)';
}

/// One long-lived connection to the TV's remote service (port 6466).
/// Keep it open while the app is in use: a key sent right after connecting is dropped by the TV, so
/// [connect] waits until the TV is ready; reconnecting for every command would be slow and unreliable.
class RemoteConnection {
  RemoteConnection._(this._socket, this._clientName) {
    _socket.onFrame = _handle;
    _socket.done.then((_) {
      if (!_started.isCompleted) _started.completeError(StateError('the TV closed the connection'));
      _states.close();
    });
  }

  static const port = 6466;
  static const _features = 1 + 2 + 32 + 64 + 512; // ping, key, power, volume, app link
  static const settle = Duration(milliseconds: 1500);

  final TvSocket _socket;
  final String _clientName;
  final Completer<void> _started = Completer<void>();
  final StreamController<TvState> _states = StreamController<TvState>.broadcast();
  int _features0 = 0;
  TvState _state = const TvState();

  TvState get state => _state;

  /// The fingerprint (SHA-256, hex) of the certificate this TV presented.
  String? get tvFingerprint => _socket.peerFingerprint;
  Stream<TvState> get states => _states.stream;
  bool get isClosed => _socket.isClosed;
  Future<void> get done => _socket.done;

  /// [clientName] is how this phone is named in the TV's own lists of remotes.
  /// [pin] is the TV's certificate fingerprint saved at pairing ([Pairing.tvFingerprint]); a TV with another certificate is refused
  /// with [TvCertificateChanged]. Without it the connection is accepted and [tvFingerprint] tells what to save.
  static Future<RemoteConnection> connect(String host, Identity identity,
      {Duration timeout = const Duration(seconds: 15), String clientName = 'Voice remote', String? pin}) async {
    final socket = await TvSocket.connect(host, port, identity, pin: pin);
    final c = RemoteConnection._(socket, clientName);
    try {
      await c._started.future.timeout(timeout);
      await Future<void>.delayed(settle); // the TV registers its virtual input device about 0.15 s after the handshake
    } catch (_) {
      socket.close();
      rethrow;
    }
    return c;
  }

  // ---- commands ----
  void key(int code) => _socket.send(fBytes(10, concat([fInt(1, code), fInt(2, 3)]))); // direction 3 = short press

  void app(String link) => _socket.send(fBytes(90, fStr(1, link)));

  /// Opens an installed app by package name (the TV's launcher or Play Store resolves market://launch).
  void launchPackage(String package) => app('market://launch?id=$package');

  /// Wakes the screen (and ends the screensaver) by going Home.
  Future<void> wake() async {
    key(Keys.home);
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  Future<void> setMuted(bool on) async {
    if (_state.muted == on) return;
    key(Keys.mute);
    await _waitFor(() => _state.muted == on, const Duration(seconds: 3));
  }

  /// Steps the volume to [target] (0 to the TV's maximum). Sends the presses back to back, waits for the
  /// level to settle and corrects any remainder. Returns the level the TV ends up reporting.
  Future<int> setVolume(int target) async {
    final goal = target.clamp(0, _state.volumeMax);
    for (var round = 0; round < 4; round++) {
      final delta = goal - _state.volume;
      if (delta == 0) break;
      for (var i = 0; i < delta.abs(); i++) {
        key(delta > 0 ? Keys.volumeUp : Keys.volumeDown);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      var last = _state.volume;
      var quiet = DateTime.now();
      final limit = DateTime.now().add(const Duration(seconds: 6));
      while (DateTime.now().difference(quiet) < const Duration(milliseconds: 800) && DateTime.now().isBefore(limit)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (_state.volume != last) {
          last = _state.volume;
          quiet = DateTime.now();
        }
      }
    }
    return _state.volume;
  }

  Future<void> volumeBy(int delta) => setVolume(_state.volume + delta);

  void close() => _socket.close();

  // ---- incoming messages ----
  void _handle(Uint8List raw) {
    final m = parseFields(raw);
    if (m.has(1)) {
      final cfg = m.subOf(1)!;
      final dev = cfg.subOf(2);
      _features0 = _features & (cfg.intOf(1) ?? 0);
      final device = concat([
        fStr(1, _clientName),
        fStr(2, 'Unofficial'),
        fInt(3, 1),
        fStr(4, '1'),
        fStr(5, 'atvremote'),
        fStr(6, '1.0.0'),
      ]);
      _socket.send(fBytes(1, concat([fInt(1, _features0), fBytes(2, device)])));
      _emit(_state.copyWith(model: dev?.stringOf(1)));
    }
    if (m.has(2)) _socket.send(fBytes(2, fInt(1, _features0)));
    if (m.has(8)) _socket.send(fBytes(9, fInt(1, m.subOf(8)!.intOf(1) ?? 0)));
    if (m.has(40)) {
      _emit(_state.copyWith(screenOn: (m.subOf(40)!.intOf(1) ?? 1) != 0));
      if (!_started.isCompleted) _started.complete();
    }
    if (m.has(50)) {
      final v = m.subOf(50)!;
      _emit(_state.copyWith(
        volume: v.intOf(7) ?? _state.volume,
        volumeMax: v.intOf(6) ?? _state.volumeMax,
        muted: (v.intOf(8) ?? 0) != 0,
      ));
    }
    if (m.has(20)) {
      final app = m.subOf(20)!.subOf(1)?.stringOf(12);
      if (app != null) _emit(_state.copyWith(app: app));
    }
  }

  void _emit(TvState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  Future<void> _waitFor(bool Function() test, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (!test() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
