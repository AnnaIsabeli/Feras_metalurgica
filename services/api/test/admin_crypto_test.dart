import 'dart:convert';
import 'package:fera_api/src/admin/admin_crypto.dart';
import 'package:test/test.dart';

void main() {
  test('TOTP matches RFC6238 SHA1 vectors and rejects replay', () {
    final secret = ascii.encode('12345678901234567890');
    for (final vector in {
      59: '94287082',
      1111111109: '07081804',
      1111111111: '14050471',
      1234567890: '89005924',
      2000000000: '69279037',
      20000000000: '65353130',
    }.entries) {
      expect(
        AdminCrypto.totp(secret, vector.key ~/ 30, digits: 8),
        vector.value,
      );
    }
    final now = DateTime.fromMillisecondsSinceEpoch(
      1234567890 * 1000,
      isUtc: true,
    );
    final counter = now.millisecondsSinceEpoch ~/ 30000;
    final code = AdminCrypto.totp(secret, counter);
    expect(AdminCrypto.validCounter(secret, code, now, -1), counter);
    expect(AdminCrypto.validCounter(secret, code, now, counter), isNull);
    expect(AdminCrypto.validCounter(secret, '12345x', now, -1), isNull);
  });
  test(
    'secret encryption authenticates both ciphertext and account identity',
    () async {
      final crypto = AdminCrypto(List.filled(32, 7));
      final secret = AdminCrypto.randomBytes(20);
      final encrypted = await crypto.encryptSecret('account-a', secret);
      expect(await crypto.decryptSecret('account-a', encrypted), secret);
      await expectLater(
        crypto.decryptSecret('account-b', encrypted),
        throwsA(anything),
      );
      final bytes = base64.decode(encrypted);
      bytes[14] ^= 1;
      await expectLater(
        crypto.decryptSecret('account-a', base64.encode(bytes)),
        throwsA(anything),
      );
      expect(AdminCrypto.base32(ascii.encode('foobar')), 'MZXW6YTBOI');
      expect(AdminCrypto.digest(AdminCrypto.newSession()).length, 64);
    },
  );
}
