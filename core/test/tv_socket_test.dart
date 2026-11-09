import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tv_remote_core/src/tv_socket.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

void main() {
  late Identity tv;
  late Identity phone;
  late SecureServerSocket server;
  late String tvFingerprint;

  setUpAll(() async {
    tv = await Identity.generate();
    phone = await Identity.generate();
    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(tv.certPem))
      ..usePrivateKeyBytes(utf8.encode(tv.keyPem));
    server = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, context);
    server.listen((s) => s.listen((_) {}, onError: (_) {}), onError: (_) {});
    tvFingerprint = certificateFingerprint(pemToDer(tv.certPem));
  });

  tearDownAll(() => server.close());

  test('without a pin any certificate is accepted, and its fingerprint is reported (a pairing made before pins existed)', () async {
    final s = await TvSocket.connect('127.0.0.1', server.port, phone);
    expect(s.peerFingerprint, tvFingerprint);
    s.close();
  });

  test('the certificate saved at pairing is accepted (case does not matter)', () async {
    final a = await TvSocket.connect('127.0.0.1', server.port, phone, pin: tvFingerprint);
    a.close();
    final b = await TvSocket.connect('127.0.0.1', server.port, phone, pin: tvFingerprint.toUpperCase());
    b.close();
  });

  test('another certificate than the one saved at pairing is refused', () async {
    final other = certificateFingerprint(pemToDer(phone.certPem)); // some other certificate's fingerprint
    await expectLater(
      TvSocket.connect('127.0.0.1', server.port, phone, pin: other),
      throwsA(isA<TvCertificateChanged>()
          .having((e) => e.expected, 'expected', other)
          .having((e) => e.actual, 'actual', tvFingerprint)),
    );
  });

  test('the fingerprint is the lowercase hex SHA-256 of the certificate bytes', () {
    // SHA-256 of the empty input, a published test vector
    expect(certificateFingerprint(const []), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  });
}
