import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'identity.dart';
import 'tv_socket.dart';
import 'wire.dart';

class PairingException implements Exception {
  PairingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pairing with the TV (port 6467). [begin] makes the TV show a 6-character code; [finish] takes it.
class Pairing {
  Pairing._(this._socket, this._identity);

  final TvSocket _socket;
  final Identity _identity;

  static const port = 6467;

  static Future<Pairing> begin(String host, Identity identity, {String clientName = 'Voice remote'}) async {
    final socket = await TvSocket.connect(host, port, identity);
    final p = Pairing._(socket, identity);
    try {
      socket.send(_outer(10, concat([fStr(1, 'atvremote'), fStr(2, clientName)])));
      await p._expect(11, 'pairing request ack');
      final encoding = concat([fInt(1, 3), fInt(2, 6)]); // hexadecimal, 6 symbols
      socket.send(_outer(20, concat([fBytes(1, encoding), fInt(3, 1)]))); // options, preferred role: input
      await p._expect(20, 'options');
      socket.send(_outer(30, concat([fBytes(1, encoding), fInt(2, 1)]))); // configuration
      await p._expect(31, 'configuration ack');
      return p;
    } catch (_) {
      socket.close();
      rethrow;
    }
  }

  /// [code] is the 6 hexadecimal characters shown on the TV.
  Future<void> finish(String code) async {
    final c = code.replaceAll(' ', '').toUpperCase();
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(c)) throw PairingException('The code is 6 letters or digits (0-9, A-F).');
    final serverDer = _socket.peerCertificateDer;
    if (serverDer == null) throw PairingException('No certificate from the TV.');
    final (cn, ce) = _identity.publicNumbers;
    final (sn, se) = rsaNumbersFromCertDer(serverDer);
    final input = concat([
      bigIntToBytes(cn),
      bigIntToBytes(ce),
      bigIntToBytes(sn),
      bigIntToBytes(se),
      _hex(c.substring(2)),
    ]);
    final digest = sha256.convert(input).bytes;
    if (digest[0] != int.parse(c.substring(0, 2), radix: 16)) {
      throw PairingException('That code does not match. Check it on the TV and try again.');
    }
    _socket.send(_outer(40, fBytes(1, digest)));
    await _expect(41, 'secret ack');
    _socket.close();
  }

  void cancel() => _socket.close();

  Future<void> _expect(int field, String what) async {
    final msg = parseFields(await _socket.next(timeout: const Duration(seconds: 15)));
    final status = msg.intOf(2) ?? 0;
    if (status != 200 || !msg.has(field)) {
      throw PairingException('Pairing failed at "$what" (status $status).');
    }
  }

  static Uint8List _outer(int field, List<int> body) =>
      concat([fInt(1, 2), fInt(2, 200), fBytes(field, body)]); // protocol 2, status OK

  static Uint8List _hex(String s) {
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
