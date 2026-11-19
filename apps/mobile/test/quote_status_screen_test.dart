import 'dart:convert';
import 'package:fera_contracts/fera_contracts.dart';
import 'package:fera_mobile/core/api_client.dart';
import 'package:fera_mobile/features/quotes/quote_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('approval submits the displayed saved pricing revision', (
    tester,
  ) async {
    final quote = QuoteRequest(
      id: 'quote-id',
      buyerId: null,
      product: 'Portão',
      description: 'Teste',
      quantity: 1,
      status: RequestStatus.pending,
      createdAt: DateTime.utc(2026, 11, 19),
      pricingId: 'saved-revision',
      unitPriceCents: 5000,
    );
    Map<String, dynamic>? posted;
    final api = ApiClient(
      baseUrl: 'http://localhost',
      token: 'seller',
      client: MockClient((request) async {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({...quote.toJson(), 'status': 'approved'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    await tester.binding.setSurfaceSize(const Size(1100, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: QuoteDetailScreen(item: quote, seller: true, api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Aprovado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(posted, {
      'status': 'approved',
      'expectedStatus': 'pending',
      'expectedPricingId': 'saved-revision',
    });
    expect(find.text('Em produção'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
