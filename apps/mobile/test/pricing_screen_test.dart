import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fera_mobile/core/api_client.dart';
import 'package:fera_mobile/features/pricing/pricing_screen.dart';

void main() {
  test('accepts comma decimals and rejects ambiguous thousands', () {
    expect(parseDecimal(' 12,50 '), 12.5);
    expect(parseDecimal('1.200,50'), isNull);
    expect(money(123.456), 'R\$ 123,46');
  });
  testWidgets(
    'seller submits costs, sees server result, invalidates it after editing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? submitted;
      final api = ApiClient(
        baseUrl: 'http://localhost',
        token: 'demo-seller',
        client: MockClient((request) async {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'cmv': 100,
              'divisor': 1,
              'markupMultiplier': 1,
              'suggested': {
                'revenue': 100,
                'cmv': 100,
                'variableExpenses': 0,
                'contributionMargin': 0,
                'fixedExpenses': 0,
                'netProfit': 0,
                'contributionMarginRate': 0,
                'netMarginRate': 0,
              },
              'practiced': null,
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: PricingScreen(api: api)));
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Material e unidade (ex.: Metalon / metro)',
        ),
        'Aço / kg',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Custo por unidade (R\$)'),
        '100,00',
      );
      await tester.ensureVisible(find.text('Calcular preço'));
      await tester.tap(find.text('Calcular preço'));
      await tester.pumpAndSettle();
      expect(submitted!['costs'][0]['unitCost'], 100);
      expect(submitted!['rates']['targetNetMarginRate'], 0);
      await tester.ensureVisible(find.text('Preço sugerido'));
      expect(find.text('Preço sugerido'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Custo por unidade (R\$)'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Custo por unidade (R\$)'),
        '200',
      );
      await tester.pump();
      expect(find.text('Preço sugerido'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty material form stays local and shows validation', (
    tester,
  ) async {
    var calls = 0;
    final api = ApiClient(
      baseUrl: 'http://localhost',
      token: 'demo-seller',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: PricingScreen(api: api)));
    await tester.ensureVisible(find.text('Calcular preço'));
    await tester.tap(find.text('Calcular preço'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Informe o material.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
