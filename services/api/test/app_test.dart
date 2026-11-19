import 'dart:convert';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/core/config.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/materials/material_service.dart';
import 'support/memory_repositories.dart';
import 'package:fera_api/src/quotes/quote_service.dart';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late MemoryQuotes repository;
  late MemoryMaterials materialsRepository;
  late Handler handler;
  setUp(() {
    repository = MemoryQuotes();
    materialsRepository = MemoryMaterials();
    handler = buildHandler(
      quotes: QuoteService(repository),
      materials: MaterialService(materialsRepository),
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
      'origin': ?origin,
      'content-type': 'application/json',
    },
    body: body == null ? null : jsonEncode(body),
  );
  final valid = {
    'product': 'Portão',
    'description': 'Portão de correr de 3 metros',
    'quantity': 1,
  };

  test('catálogo: só administrador altera e vendedor aprovado consulta ativos', () async {
    final denied = await handler(request(
      'POST', '/v1/materials', token: 'demo-seller',
      body: {'name': 'Aço', 'unit': 'kg', 'unitCost': '12.5'},
    ));
    expect(denied.statusCode, 403);

    final buyerDenied = await handler(request('GET', '/v1/materials', token: 'demo-buyer'));
    expect(buyerDenied.statusCode, 403);

    final created = await handler(request(
      'POST', '/v1/materials', token: 'demo-admin',
      body: {'name': 'Aço carbono', 'unit': 'kg', 'unitCost': '12.500000'},
    ));
    expect(created.statusCode, 201);

    final sellerRead = await handler(request('GET', '/v1/materials', token: 'demo-seller'));
    expect(sellerRead.statusCode, 200);
    final invalid = await handler(request(
      'POST', '/v1/materials', token: 'demo-admin',
      body: {'name': ' ', 'unit': 'kg', 'unitCost': '-1'},
    ));
    expect(invalid.statusCode, 422);
  });

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
  test('seller must identify the customer when creating a request', () async {
    expect(
      (await handler(
        request(
          'POST',
          '/v1/quote-requests',
          token: 'demo-seller',
          body: valid,
        ),
      )).statusCode,
      422,
    );
  });
  test(
    'approved seller creates a customer request without a buyer account',
    () async {
      final result = await handler(
        request(
          'POST',
          '/v1/quote-requests',
          token: 'demo-seller',
          body: {
            ...valid,
            'customerName': ' Cliente WhatsApp ',
            'customerContact': ' contato ',
            'buyerId': 'forged',
            'createdBy': 'forged',
            'status': 'quoted',
          },
        ),
      );
      expect(result.statusCode, 201);
      final body = jsonDecode(await result.readAsString()) as Map;
      expect(body['buyerId'], isNull);
      expect(body['createdBy'], DevelopmentIdentityVerifier.sellerId);
      expect(body['customerName'], 'Cliente WhatsApp');
      expect(body['customerContact'], 'contato');
      expect(body['status'], 'received');
      final buyerItems = await QuoteService(repository).list(
        const Principal(DevelopmentIdentityVerifier.buyerId, UserRole.buyer),
      );
      expect(buyerItems, isEmpty);
    },
  );
  test('unapproved seller cannot create customer requests', () async {
    expect(
      () => QuoteService(repository).create(
        const Principal('pending', UserRole.seller),
        {...valid, 'customerName': 'Cliente'},
      ),
      throwsA(anything),
    );
    expect(repository.items, isEmpty);
  });
  test('buyer cannot inject customer details or another creator', () async {
    final item = await QuoteService(repository)
        .create(const Principal('buyer', UserRole.buyer), {
          ...valid,
          'createdBy': 'forged',
          'customerName': 'Someone else',
          'customerContact': 'private',
        });
    expect(item.createdBy, 'buyer');
    expect(item.buyerId, 'buyer');
    expect(item.customerName, isNull);
    expect(item.customerContact, isNull);
  });
  test('invalid customer details are rejected', () async {
    for (final extra in [
      {'customerName': ' '},
      {'customerName': 'x' * 121},
      {'customerName': 'Cliente', 'customerContact': 123},
      {'customerName': 'Cliente', 'customerContact': 'x' * 121},
    ]) {
      expect(
        (await handler(
          request(
            'POST',
            '/v1/quote-requests',
            token: 'demo-seller',
            body: {...valid, ...extra},
          ),
        )).statusCode,
        422,
      );
    }
    expect(repository.items, isEmpty);
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
        materials: MaterialService(materialsRepository),
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
