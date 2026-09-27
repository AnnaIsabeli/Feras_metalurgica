import 'dart:convert';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'app_test.dart' show MemoryQuotes;

void main() {
  final handler = buildHandler(
    quotes: QuoteService(MemoryQuotes()),
    identity: DevelopmentIdentityVerifier(),
    checkDatabase: () async {},
    allowedOrigin: 'http://localhost:5000, https://demo.example.com',
  );
  Map<String, dynamic> payload() => {
    'costs': [
      {'name': 'Aço', 'quantity': 2, 'unitCost': 50},
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
  Future<Response> post({
    String? token = 'demo-seller',
    Object? body,
    String origin = 'https://demo.example.com',
    String type = 'application/json',
  }) async => handler(
    Request(
      'POST',
      Uri.parse('http://localhost/v1/pricing/calculate'),
      headers: {
        if (token != null) 'authorization': 'Bearer $token',
        'content-type': type,
        'origin': origin,
      },
      body: body is String ? body : jsonEncode(body ?? payload()),
    ),
  );
  test('approved seller calculates suggested and negotiated results', () async {
    final response = await post();
    expect(response.statusCode, 200);
    expect(
      response.headers['access-control-allow-origin'],
      'https://demo.example.com',
    );
    final body = jsonDecode(await response.readAsString());
    expect(body['cmv'], 100);
    expect(body['suggested']['revenue'], closeTo(100 / .355, .000001));
    expect(body['practiced']['netProfit'], closeTo(51.5, .000001));
  });
  test('buyers and anonymous users cannot calculate', () async {
    expect((await post(token: 'demo-buyer')).statusCode, 403);
    expect((await post(token: null)).statusCode, 401);
  });
  test('invalid JSON, media type and large payload fail explicitly', () async {
    expect((await post(body: '{')).statusCode, 400);
    expect((await post(type: 'text/plain')).statusCode, 415);
    expect((await post(body: 'x' * 17000)).statusCode, 413);
  });
  test('invalid structures, rates and divisor are rejected', () async {
    expect((await post(body: {'costs': 'invalid'})).statusCode, 422);
    final data = payload();
    (data['rates'] as Map)['targetNetMarginRate'] = .9;
    expect((await post(body: data)).statusCode, 422);
    (data['rates'] as Map)['targetNetMarginRate'] = '15';
    expect((await post(body: data)).statusCode, 422);
  });
  test('origin allowlist matches complete origins only', () async {
    expect(
      (await post(origin: 'https://demo.example.com.evil.test')).statusCode,
      403,
    );
    expect((await post(origin: 'http://localhost:5000')).statusCode, 200);
  });
}
