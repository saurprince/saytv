import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'identity.dart';
import 'wire.dart';

/// A TLS connection to the TV that speaks length-prefixed protobuf messages.
/// The TV's certificate is self-signed, so it is accepted here; the pairing code is what proves the TV.
class TvSocket {
  TvSocket._(this._socket) {
    _socket.listen(_onData, onError: _onError, onDone: _onDone, cancelOnError: true);
  }

  final SecureSocket _socket;
  final FrameReader _reader = FrameReader();
  final List<Uint8List> _queue = [];
  final Completer<void> _closed = Completer<void>();
  Completer<void>? _wake;
  Object? error;

  /// If set, every message goes here instead of the queue read by [next].
  void Function(Uint8List frame)? onFrame;

  Future<void> get done => _closed.future;
  bool get isClosed => _closed.isCompleted;

  static Future<TvSocket> connect(String host, int port, Identity identity,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(identity.certPem))
      ..usePrivateKeyBytes(utf8.encode(identity.keyPem));
    final socket = await SecureSocket.connect(host, port,
        context: context, onBadCertificate: (_) => true, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    return TvSocket._(socket);
  }

  /// The TV's certificate (DER), available after the TLS handshake.
  Uint8List? get peerCertificateDer => _socket.peerCertificate?.der;

  void send(List<int> message) => _socket.add(frame(message));

  Future<Uint8List> next({Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (_queue.isEmpty) {
      if (isClosed) throw SocketException('the TV closed the connection${error == null ? '' : ' ($error)'}');
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) throw TimeoutException('no message from the TV', timeout);
      _wake = Completer<void>();
      await _wake!.future.timeout(left, onTimeout: () {});
    }
    return _queue.removeAt(0);
  }

  void close() {
    _socket.destroy();
    if (!_closed.isCompleted) _closed.complete();
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _onData(Uint8List data) {
    _reader.add(data);
    for (final f in _reader.takeFrames()) {
      if (onFrame != null) {
        onFrame!(f);
      } else {
        _queue.add(f);
      }
    }
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _onError(Object e) {
    error = e;
    _onDone();
  }

  void _onDone() {
    if (!_closed.isCompleted) _closed.complete();
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }
}
