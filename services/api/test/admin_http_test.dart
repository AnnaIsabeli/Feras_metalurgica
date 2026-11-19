import 'package:fera_api/src/admin/admin_crypto.dart';
import 'package:fera_api/src/admin/admin_service.dart';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'app_test.dart' show MemoryQuotes;

class AdminTestIdentity implements IdentityVerifier {
  @override
  Future<Principal?> verify(String token) async => switch (token) {
    'admin' => Principal(
      'owner',
      UserRole.buyer,
      adminEligible: true,
      googleVerified: true,
      tokenIssuedAt: DateTime.now(),
    ),
    'seller' => const Principal(
      'seller',
      UserRole.seller,
      sellerApproved: true,
      googleVerified: true,
    ),
    _ => null,
  };
}

void main() {
  late Pool pool;
  late Handler handler;
  setUp(() {
    pool = Pool.withUrl(
      'postgresql://unused:unused@localhost:1/unused?sslmode=disable',
    );
    handler = buildHandler(
      quotes: QuoteService(MemoryQuotes()),
      identity: AdminTestIdentity(),
      admin: AdminService(pool, AdminCrypto(List.filled(32, 1))),
      checkDatabase: () async {},
      allowedOrigin: 'https://orcex.shop,http://localhost:5000',
    );
  });
  tearDown(() async {
    await pool.close();
  });
  Request request(
    String path, {
    String? token,
    String? origin,
    String method = 'POST',
  }) => Request(
    method,
    Uri.parse('https://orcex.shop$path'),
    headers: {
      if (token != null) 'authorization': 'Bearer $token',
      if (origin != null) 'origin': origin,
      'content-type': 'application/json',
    },
    body: method == 'GET' ? null : '{}',
  );
  test(
    'public administration rejects anonymous users, sellers and missing MFA',
    () async {
      for (final endpoint in [
        '/v1/admin/enrollment',
        '/v1/admin/session',
        '/v1/admin/invitations',
      ]) {
        expect((await handler(request(endpoint))).statusCode, 401);
        expect(
          (await handler(request(endpoint, token: 'seller'))).statusCode,
          403,
        );
      }
      final response = await handler(
        request('/v1/admin/overview', token: 'admin', method: 'GET'),
      );
      expect(response.statusCode, 401);
      expect(response.headers['cache-control'], contains('no-store'));
    },
  );
  test(
    'administration rejects a different origin even if regular API permits it',
    () async {
      final response = await handler(
        request(
          '/v1/admin/enrollment',
          token: 'admin',
          origin: 'http://localhost:5000',
        ),
      );
      expect(response.statusCode, 403);
      expect(await response.readAsString(), contains('origin_denied'));
    },
  );
  test(
    'administrator role is not exposed as seller and requires configured feature',
    () async {
      final disabled = buildHandler(
        quotes: QuoteService(MemoryQuotes()),
        identity: AdminTestIdentity(),
        checkDatabase: () async {},
        allowedOrigin: 'https://orcex.shop',
      );
      expect(
        (await disabled(
          request('/v1/admin/overview', token: 'admin', method: 'GET'),
        )).statusCode,
        404,
      );
      expect(
        await (await disabled(
          request('/v1/me', token: 'admin', method: 'GET'),
        )).readAsString(),
        contains('"adminEligible":false'),
      );
    },
  );
}
