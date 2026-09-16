import 'dart:convert';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/core/config.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/quotes/quote_repository.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:fera_contracts/fera_contracts.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class MemoryQuotes implements QuoteRepository {
  final items = <QuoteRequest>[];
  @override
  Future<QuoteRequest> create(QuoteRequest request) async {
    items.add(request);
    return request;
  }

  @override
  Future<List<QuoteRequest>> list({String? buyerId}) async =>
      items.where((q) => buyerId == null || q.buyerId == buyerId).toList();
}

void main() {
  late MemoryQuotes repository;
  late Handler handler;
  setUp(() {
    repository = MemoryQuotes();
    handler = buildHandler(
      quotes: QuoteService(repository),
      identity: DevelopmentIdentityVerifier(),
      checkDatabase: () async {},
      allowedOrigin: 'http://localhost:5000',
    );
  });
  Request request(
    String method,
    String path, {
    String? token,
    Object? body,
    String? origin,
  }) => Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {
      if (token != null) 'authorization': 'Bearer $token',
      if (origin != null) 'origin': origin,
      'content-type': 'application/json',
    },
    body: body == null ? null : jsonEncode(body),
  );
  final valid = {
    'product': 'Portão',
    'description': 'Portão de correr de 3 metros',
    'quantity': 1,
  };

  test('health is public but quote requests require authentication', () async {
    expect((await handler(request('GET', '/health'))).statusCode, 200);
    expect(
      (await handler(request('GET', '/v1/quote-requests'))).statusCode,
      401,
    );
  });
  test(
    'buyer creates request; server ignores forged ownership and status',
    () async {
      final result = await handler(
        request(
          'POST',
          '/v1/quote-requests',
          token: 'demo-buyer',
          body: {...valid, 'buyerId': 'forged', 'status': 'quoted'},
        ),
      );
      expect(result.statusCode, 201);
      final body = jsonDecode(await result.readAsString()) as Map;
      expect(body['buyerId'], DevelopmentIdentityVerifier.buyerId);
      expect(body['status'], 'received');
    },
  );
  test('seller cannot impersonate a buyer to create a request', () async {
    expect(
      (await handler(
        request(
          'POST',
          '/v1/quote-requests',
          token: 'demo-seller',
          body: valid,
        ),
      )).statusCode,
      403,
    );
  });
  test(
    'invalid quantities, blank text and oversized text are rejected',
    () async {
      for (final data in [
        {...valid, 'quantity': 0},
        {...valid, 'quantity': 1.5},
        {...valid, 'quantity': 10001},
        {...valid, 'product': '  '},
        {...valid, 'description': 'a' * 4001},
      ]) {
        expect(
          (await handler(
            request(
              'POST',
              '/v1/quote-requests',
              token: 'demo-buyer',
              body: data,
            ),
          )).statusCode,
          422,
        );
      }
      expect(repository.items, isEmpty);
    },
  );
  test('buyer only sees own data; approved seller sees requests', () async {
    final service = QuoteService(repository);
    await service.create(const Principal('buyer-a', UserRole.buyer), valid);
    await service.create(const Principal('buyer-b', UserRole.buyer), valid);
    expect(
      await service.list(const Principal('buyer-a', UserRole.buyer)),
      hasLength(1),
    );
    expect(
      await service.list(
        const Principal('seller', UserRole.seller, sellerApproved: true),
      ),
      hasLength(2),
    );
    expect(
      () => service.list(const Principal('seller', UserRole.seller)),
      throwsA(anything),
    );
  });
  test(
    'invalid JSON, disallowed origin and oversized body have explicit errors',
    () async {
      final malformed = Request(
        'POST',
        Uri.parse('http://localhost/v1/quote-requests'),
        headers: {
          'authorization': 'Bearer demo-buyer',
          'content-type': 'application/json',
        },
        body: '{',
      );
      expect((await handler(malformed)).statusCode, 400);
      expect(
        (await handler(
          request('GET', '/health', origin: 'https://untrusted.example'),
        )).statusCode,
        403,
      );
      expect(
        (await handler(
          request(
            'POST',
            '/v1/quote-requests',
            token: 'demo-buyer',
            body: {'x': 'a' * 17000},
          ),
        )).statusCode,
        413,
      );
    },
  );
  test(
    'database unavailable produces readiness 503 without internal details',
    () async {
      final app = buildHandler(
        quotes: QuoteService(repository),
        identity: DenyAllIdentityVerifier(),
        checkDatabase: () async =>
            throw StateError('private connection details'),
        allowedOrigin: 'http://localhost:5000',
      );
      final result = await app(request('GET', '/ready'));
      expect(result.statusCode, 503);
      expect(await result.readAsString(), isNot(contains('private')));
    },
  );
  test('development authentication cannot be enabled in production', () {
    expect(
      () => AppConfig.fromEnvironment({
        'DATABASE_URL': 'postgresql://localhost/fera',
        'APP_ENV': 'production',
        'DEV_AUTH_ENABLED': 'true',
      }),
      throwsStateError,
    );
  });
}
