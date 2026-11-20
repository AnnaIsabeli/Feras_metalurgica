import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

class AdminCrypto {
  AdminCrypto(List<int> key) : key = SecretKey(key) {
    if (key.length != 32) {
      throw ArgumentError('ADMIN_MFA_KEY must contain 32 bytes.');
    }
  }
  final SecretKey key;
  final cipher = AesGcm.with256bits();
  static List<int> randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static String digest(String value) =>
      hashes.sha256.convert(utf8.encode(value)).toString();
  static String newSession() =>
      base64Url.encode(randomBytes(32)).replaceAll('=', '');
  Future<String> encryptSecret(String userId, List<int> secret) async {
    final box = await cipher.encrypt(
      secret,
      secretKey: key,
      aad: utf8.encode(userId),
    );
    return base64.encode(box.concatenation());
  }

  Future<List<int>> decryptSecret(String userId, String encrypted) =>
      cipher.decrypt(
        SecretBox.fromConcatenation(
          base64.decode(encrypted),
          nonceLength: 12,
          macLength: 16,
        ),
        secretKey: key,
        aad: utf8.encode(userId),
      );
  static String base32(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var value = 0, bits = 0;
    final result = StringBuffer();
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        result.write(alphabet[(value >> bits) & 31]);
      }
      value &= (1 << bits) - 1;
    }
    if (bits > 0) result.write(alphabet[(value << (5 - bits)) & 31]);
    return result.toString();
  }

  static String totp(List<int> secret, int counter, {int digits = 6}) {
    final bytes = ByteData(8)..setUint64(0, counter, Endian.big);
    final mac = hashes.Hmac(
      hashes.sha1,
      secret,
    ).convert(bytes.buffer.asUint8List()).bytes;
    final offset = mac.last & 15;
    final number =
        ((mac[offset] & 127) << 24) |
        (mac[offset + 1] << 16) |
        (mac[offset + 2] << 8) |
        mac[offset + 3];
    return (number % pow(10, digits).toInt()).toString().padLeft(digits, '0');
  }

  static int? validCounter(
    List<int> secret,
    String code,
    DateTime now,
    int lastCounter,
  ) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return null;
    final current = now.toUtc().millisecondsSinceEpoch ~/ 30000;
    for (final step in [current, current - 1, current + 1]) {
      if (step <= lastCounter) continue;
      final expected = totp(secret, step);
      var difference = 0;
      for (var i = 0; i < 6; i++) {
        difference |= code.codeUnitAt(i) ^ expected.codeUnitAt(i);
      }
      if (difference == 0) return step;
    }
    return null;
  }
}
