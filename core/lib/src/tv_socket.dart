import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'identity.dart';
import 'wire.dart';

/// The SHA-256 fingerprint of a certificate (its DER bytes), as lowercase hex.
String certificateFingerprint(List<int> der) => sha256.convert(der).toString();

/// The TV presented a different certificate from the one saved when this phone paired with it.
/// That happens after the TV is factory reset (it makes a new one), but it is also what someone on the network pretending to be the TV looks like.
class TvCertificateChanged implements Exception {
  const TvCertificateChanged(this.expected, this.actual);
  final String expected;
  final String actual;
  @override
  String toString() => 'the TV presented a different certificate than at pairing';
}

/// A TLS connection to the TV that speaks length-prefixed protobuf messages.
/// The TV's certificate is self-signed, so there is no authority to check it against. Instead the pairing code proves the TV once,
/// and its certificate's fingerprint is then pinned: a later connection must present the same certificate.
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

  /// [pin]: the fingerprint saved at pairing. If given, a TV with any other certificate is refused with [TvCertificateChanged].
  /// Without a pin (pairing itself, or a pairing made before pins existed) any certificate is accepted; see [peerFingerprint].
  static Future<TvSocket> connect(String host, int port, Identity identity,
      {Duration timeout = const Duration(seconds: 8), String? pin}) async {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(identity.certPem))
      ..usePrivateKeyBytes(utf8.encode(identity.keyPem));
    String? seen;
    final SecureSocket socket;
    try {
      socket = await SecureSocket.connect(host, port, context: context, timeout: timeout, onBadCertificate: (cert) {
        // withTrustedRoots is off, so every certificate lands here: this is where the pin is checked.
        seen = certificateFingerprint(cert.der);
        return pin == null || seen == pin.toLowerCase();
      });
    } on HandshakeException {
      if (pin != null && seen != null && seen != pin.toLowerCase()) throw TvCertificateChanged(pin, seen!);
      rethrow;
    }
    socket.setOption(SocketOption.tcpNoDelay, true);
    return TvSocket._(socket);
  }

  /// The TV's certificate (DER), available after the TLS handshake.
  Uint8List? get peerCertificateDer => _socket.peerCertificate?.der;

  /// The SHA-256 fingerprint (hex) of the TV's certificate, available after the TLS handshake.
  String? get peerFingerprint {
    final der = peerCertificateDer;
    return der == null ? null : certificateFingerprint(der);
  }

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
