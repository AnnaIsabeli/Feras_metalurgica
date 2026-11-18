import 'package:fera_api/src/auth/google_identity_verifier.dart';
import 'package:fera_api/src/auth/principal.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

class Accounts implements GoogleAccountRepository {
  int calls = 0;
  @override
  Future<Principal?> resolve({
    required String subject,
    required String email,
    required String name,
  }) async {
    calls++;
    expect(subject, 'google-subject');
    return const Principal('account-id', UserRole.buyer);
  }
}

void main() {
  final key = JsonWebKey.generate('RS256', keyBitLength: 2048);
  final otherKey = JsonWebKey.generate('RS256', keyBitLength: 2048);
  final clock = DateTime.utc(2026, 11, 18);
  final now = clock.millisecondsSinceEpoch ~/ 1000;
  Map<String, dynamic> claims() => {
    'iss': 'https://accounts.google.com',
    'aud': 'client-id',
    'sub': 'google-subject',
    'email': 'example@example.invalid',
    'email_verified': true,
    'iat': now,
    'exp': now + 300,
  };
  String signed(Map<String, dynamic> claims, {JsonWebKey? signingKey}) {
    final builder = JsonWebSignatureBuilder()..jsonContent = claims;
    builder.addRecipient(signingKey ?? key, algorithm: 'RS256');
    return builder.build().toCompactSerialization();
  }

  late Accounts accounts;
  late GoogleIdentityVerifier verifier;
  setUp(() {
    accounts = Accounts();
    verifier = GoogleIdentityVerifier(
      clientIds: {'client-id'},
      accounts: accounts,
      keyStore: JsonWebKeyStore()..addKey(key),
      now: () => clock,
    );
  });
  test(
    'accepts verified identity and resolves permissions from repository',
    () async {
      final value = claims()..['role'] = 'seller';
      final actor = await verifier.verify(signed(value));
      expect(actor?.role, UserRole.buyer);
      expect(accounts.calls, 1);
    },
  );
  test('rejects wrong signature without touching accounts', () async {
    expect(
      await verifier.verify(signed(claims(), signingKey: otherKey)),
      isNull,
    );
    expect(accounts.calls, 0);
  });
  for (final change in <String, dynamic>{
    'iss': 'https://attacker.invalid',
    'aud': 'other-client',
    'exp': now,
    'iat': now + 120,
    'email_verified': false,
    'sub': '',
    'azp': 'other-client',
  }.entries) {
    test('rejects invalid ${change.key}', () async {
      expect(
        await verifier.verify(signed(claims()..[change.key] = change.value)),
        isNull,
      );
      expect(accounts.calls, 0);
    });
  }
  test('rejects demo and malformed credentials', () async {
    for (final token in ['demo-seller', 'a.b.c', '', 'x' * 16385]) {
      expect(await verifier.verify(token), isNull);
    }
    expect(accounts.calls, 0);
  });
}
