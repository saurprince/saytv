import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

/// The phone's identity towards the TV: a self-signed RSA certificate and its private key (both PEM).
/// This pair IS the pairing credential. Store it in the platform's secure storage and never log or share it.
class Identity {
  Identity({required this.certPem, required this.keyPem});

  final String certPem;
  final String keyPem;

  /// Creates a new identity. RSA key generation takes a few seconds, so it runs in a separate isolate.
  static Future<Identity> generate() => Isolate.run(() {
        final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
        final priv = pair.privateKey as RSAPrivateKey;
        final pub = pair.publicKey as RSAPublicKey;
        final csr = X509Utils.generateRsaCsrPem({'CN': 'atvremote'}, priv, pub);
        final cert = X509Utils.generateSelfSignedCertificate(priv, csr, 3650);
        return Identity(certPem: cert, keyPem: CryptoUtils.encodeRSAPrivateKeyToPem(priv));
      });

  Map<String, String> toJson() => {'cert': certPem, 'key': keyPem};

  static Identity fromJson(Map<String, dynamic> j) =>
      Identity(certPem: j['cert'] as String, keyPem: j['key'] as String);

  /// The certificate's RSA modulus and exponent (they go into the pairing secret).
  (BigInt, BigInt) get publicNumbers => rsaNumbersFromCertDer(pemToDer(certPem));
}

Uint8List pemToDer(String pem) {
  final body = pem
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join()
      .replaceAll('\r', '');
  return base64.decode(body);
}

/// Reads the RSA modulus and exponent out of an X.509 certificate (DER) with a minimal ASN.1 walker.
(BigInt, BigInt) rsaNumbersFromCertDer(Uint8List der) {
  final cert = _children(der).first;
  final tbs = _children(cert.value).first;
  final fields = _children(tbs.value);
  final base = fields.first.tag == 0xA0 ? 1 : 0; // optional [0] version
  // serial, signature, issuer, validity, subject, subjectPublicKeyInfo
  final spki = _children(fields[base + 5].value);
  final bits = spki[1].value; // BIT STRING: first byte = number of unused bits
  final rsaKey = _children(Uint8List.sublistView(bits, 1)).first;
  final ints = _children(rsaKey.value);
  return (_toBigInt(ints[0].value), _toBigInt(ints[1].value));
}

/// Minimal big-endian bytes of a positive number (what the pairing hash expects).
Uint8List bigIntToBytes(BigInt v) {
  if (v == BigInt.zero) return Uint8List.fromList([0]);
  final out = <int>[];
  var n = v;
  while (n > BigInt.zero) {
    out.add((n & BigInt.from(0xff)).toInt());
    n >>= 8;
  }
  return Uint8List.fromList(out.reversed.toList());
}

BigInt _toBigInt(Uint8List bytes) {
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  return v;
}

class _Tlv {
  _Tlv(this.tag, this.value);
  final int tag;
  final Uint8List value;
}

List<_Tlv> _children(Uint8List data) {
  final out = <_Tlv>[];
  var i = 0;
  while (i < data.length) {
    final tag = data[i++];
    var len = data[i++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      len = 0;
      for (var k = 0; k < n; k++) {
        len = (len << 8) | data[i++];
      }
    }
    out.add(_Tlv(tag, Uint8List.sublistView(data, i, i + len)));
    i += len;
  }
  return out;
}
