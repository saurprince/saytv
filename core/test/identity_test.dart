import 'package:basic_utils/basic_utils.dart';
import 'package:test/test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

void main() {
  test('a generated identity has a certificate whose RSA numbers match its private key', () async {
    final id = await Identity.generate();
    final (n, e) = id.publicNumbers;
    final priv = CryptoUtils.rsaPrivateKeyFromPem(id.keyPem);
    expect(n, equals(priv.modulus));
    expect(e, equals(BigInt.from(65537)));
    expect(id.certPem, contains('BEGIN CERTIFICATE'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('bigIntToBytes gives minimal big-endian bytes', () {
    expect(bigIntToBytes(BigInt.from(65537)), [1, 0, 1]);
    expect(bigIntToBytes(BigInt.from(255)), [255]);
    expect(bigIntToBytes(BigInt.from(256)), [1, 0]);
  });
}
