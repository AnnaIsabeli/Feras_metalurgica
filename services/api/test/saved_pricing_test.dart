import 'dart:convert';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/quotes/pricing_repository.dart';
import 'package:fera_api/src/quotes/pricing_service.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'app_test.dart' show MemoryQuotes;

const requestId = '00000000-0000-4000-8000-000000000088';
const materialId = '00000000-0000-4000-8000-000000000077';
Map<String, dynamic> pricingPayload() => {
  'costs': [
    {'name': 'Aço', 'unit': 'kg', 'quantity': 2, 'unitCost': 50},
  ],
  'rates': {
    'simplesNacionalRate': .045,
    'pisCofinsRate': 0,
    'irCsllRate': 0,
    'freightRate': .03,
    'commissionRate': .02,
    'substitutionTaxRate': 0,
    'fixedExpenseRate': .4,
    'targetNetMarginRate': .15,
  },
  'practicedPrice': 300,
};

class MemoryPricings implements PricingRepository {
  Map<String, dynamic>? saved;
  bool exists = true;
  @override
  Future<List<Map<String, dynamic>>> materials() async => [
    {'id': materialId, 'name': 'Catálogo', 'unit': 'm', 'unitCost': 25.5},
  ];
  @override
  Future<Map<String, dynamic>?> material(String id) async =>
      id == materialId ? (await materials()).single : null;
  @override
  Future<Map<String, dynamic>?> latest(String id) async => saved;
  @override
  Future<Map<String, dynamic>?> save({
    required String requestId,
    required String actorId,
    required Map<String, dynamic> input,
    required Map<String, dynamic> result,
    required int totalPriceCents,
  }) async {
    if (!exists) return null;
    return saved = {
      'id': 'revision',
      'quoteRequestId': requestId,
      'createdBy': actorId,
      'totalPriceCents': totalPriceCents,
      'input': input,
      'result': result,
    };
  }
}

void main() {
  late MemoryPricings repository;
  late Handler handler;
  setUp(() {
    repository = MemoryPricings();
    handler = buildHandler(
      quotes: QuoteService(MemoryQuotes()),
      pricings: PricingService(repository),
      identity: DevelopmentIdentityVerifier(),
      checkDatabase: () async {},
      allowedOrigin: 'https://demo.example.com',
    );
  });
  Future<Response> call(
    String method, {
    String? token = 'demo-seller',
    Object? body,
    String path = '/v1/quote-requests/$requestId/pricing',
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {
        if (token != null) 'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: method == 'POST' ? jsonEncode(body ?? pricingPayload()) : null,
    ),
  );
  test('saves server calculation and retrieves the same snapshot', () async {
    final response = await call('POST');
    expect(response.statusCode, 201);
    final saved = jsonDecode(await response.readAsString());
    expect(saved['createdBy'], DevelopmentIdentityVerifier.sellerId);
    expect(saved['totalPriceCents'], 30000);
    expect(saved['result']['cmv'], 100);
    final retrieved = await call('GET');
    expect(retrieved.statusCode, 200);
    expect(jsonDecode(await retrieved.readAsString()), saved);
  });
  test('uses suggested price when no negotiated price is provided', () async {
    final data = pricingPayload()..remove('practicedPrice');
    expect((await call('POST', body: data)).statusCode, 201);
    expect(repository.saved!['totalPriceCents'], 28169);
  });
  test('catalog values override client costs and names', () async {
    final data = pricingPayload();
    (data['costs'] as List).first['materialId'] = materialId;
    expect((await call('POST', body: data)).statusCode, 201);
    expect(repository.saved!['result']['cmv'], 51);
    expect(repository.saved!['input']['costs'][0]['name'], 'Catálogo');
    expect((await call('GET', path: '/v1/materials')).statusCode, 200);
  });
  test('authentication and role protect reads, writes and materials', () async {
    for (final path in [
      '/v1/materials',
      '/v1/quote-requests/$requestId/pricing',
    ]) {
      expect((await call('GET', path: path, token: null)).statusCode, 401);
      expect(
        (await call('GET', path: path, token: 'demo-buyer')).statusCode,
        403,
      );
    }
    expect((await call('POST', token: null)).statusCode, 401);
    expect((await call('POST', token: 'demo-buyer')).statusCode, 403);
    final service = PricingService(repository);
    expect(
      () => service.materials(const Principal(requestId, UserRole.seller)),
      throwsA(isA<Exception>()),
    );
  });
  test(
    'missing request or pricing yields 404, malformed UUID yields 422',
    () async {
      expect((await call('GET')).statusCode, 404);
      repository.exists = false;
      expect((await call('POST')).statusCode, 404);
      expect(
        (await call('POST', path: '/v1/quote-requests/no/pricing')).statusCode,
        422,
      );
    },
  );
  test(
    'invalid units, decimal precision, material and divisor do not save',
    () async {
      for (final field in [
        {'unit': ''},
        {'quantity': 0},
        {'quantity': 1.1234},
        {'unitCost': -1},
        {'unitCost': 1.1234567},
        {'materialId': requestId},
      ]) {
        final data = pricingPayload();
        (data['costs'] as List).first.addAll(field);
        expect(
          (await call('POST', body: data)).statusCode,
          422,
          reason: '$field',
        );
        expect(repository.saved, isNull);
      }
      final data = pricingPayload();
      data['rates']['targetNetMarginRate'] = .9;
      expect((await call('POST', body: data)).statusCode, 422);
      expect(repository.saved, isNull);
    },
  );
}
