import 'dart:convert';

import 'package:fera_contracts/fera_contracts.dart';
import 'package:fera_mobile/core/api_client.dart';
import 'package:fera_mobile/features/pricing/pricing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
const materialId = '22222222-2222-4222-8222-222222222222';

final request = QuoteRequest(
  id: requestId,
  buyerId: 'buyer-1',
  product: 'Portão de correr',
  description: 'Abertura de 3 m, aço e madeira escura.',
  quantity: 2,
  status: RequestStatus.received,
  createdAt: DateTime.utc(2026, 11, 10, 15),
);

Map<String, dynamic> pricingResult(num revenue) => {
  'cmv': 51,
  'divisor': 1,
  'markupMultiplier': 1,
  'suggested': {
    'revenue': revenue,
    'cmv': 51,
    'variableExpenses': 0,
    'contributionMargin': 0,
    'fixedExpenses': 0,
    'netProfit': 0,
    'contributionMarginRate': 0,
    'netMarginRate': 0,
  },
  'practiced': null,
};

http.Response jsonResponse(int status, Map<String, dynamic> body) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Servidor de mentira: responde como a API real e anota o que a tela enviou.
/// Não calcula nada: devolve sempre o mesmo resultado pronto.
class FakeApi {
  int materialsStatus = 200;
  Map<String, dynamic>? saved;
  final calls = <String>[];
  final bodies = <String, Map<String, dynamic>>{};

  ApiClient client() => ApiClient(
    baseUrl: 'http://localhost',
    token: 'demo-seller',
    client: MockClient(handle),
  );

  Future<http.Response> handle(http.Request r) async {
    final route = '${r.method} ${r.url.path}';
    calls.add(route);
    final body = r.body.isEmpty
        ? null
        : jsonDecode(r.body) as Map<String, dynamic>;
    if (body != null) bodies[route] = body;

    if (route == 'GET /v1/materials') {
      return materialsStatus == 200
          ? jsonResponse(200, {
              'items': [
                {
                  'id': materialId,
                  'name': 'Metalon',
                  'unit': 'm',
                  'unitCost': 25.5,
                },
              ],
            })
          : jsonResponse(materialsStatus, {
              'error': {
                'code': 'internal_error',
                'message': 'Falha ao carregar materiais.',
              },
            });
    }
    if (route == 'GET /v1/quote-requests/$requestId/pricing') {
      return saved == null
          ? jsonResponse(404, {
              'error': {
                'code': 'pricing_not_found',
                'message': 'Nenhuma precificação encontrada.',
              },
            })
          : jsonResponse(200, saved!);
    }
    if (route == 'POST /v1/pricing/calculate') {
      return jsonResponse(200, pricingResult(100));
    }
    if (route == 'POST /v1/quote-requests/$requestId/pricing') {
      final costs = (body!['costs'] as List).cast<Map<String, dynamic>>();
      saved = {
        'id': 'pricing-1',
        'quoteRequestId': requestId,
        'createdBy': 'seller-1',
        'createdAt': '2026-11-11T20:00:00.000Z',
        'totalPriceCents': 10000,
        'input': {
          'costs': [
            for (final cost in costs)
              cost['materialId'] == null
                  ? cost
                  : {
                      'materialId': materialId,
                      'name': 'Metalon',
                      'unit': 'm',
                      'quantity': cost['quantity'],
                      'unitCost': 25.5,
                    },
          ],
          'rates': body['rates'],
        },
        'result': pricingResult(100),
      };
      return jsonResponse(201, saved!);
    }
    return jsonResponse(404, {
      'error': {'code': 'not_found', 'message': 'Rota inesperada: $route'},
    });
  }
}

Future<void> openScreen(
  WidgetTester tester,
  FakeApi server, {
  QuoteRequest? forRequest,
}) async {
  await tester.binding.setSurfaceSize(const Size(1100, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = server.client();
  addTearDown(api.close);
  // Troca a tela inteira para garantir um estado novo (como "fechar e abrir").
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(home: PricingScreen(api: api, request: forRequest)),
  );
  await tester.pumpAndSettle();
}

Future<void> pickFromDropdown(WidgetTester tester, String option) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  test('decimal helpers', () {
    expect(parseDecimal(' 12,50 '), 12.5);
    expect(parseDecimal('1.200,50'), isNull);
    expect(money(123.456), 'R\$ 123,46');
    expect(formatDecimal(4.5), '4,5');
    expect(formatDecimal(100), '100');
    expect(formatDecimal(0.07 * 100), '7');
    expect(formatDecimal(0), '0');
    expect(decimalPlaces('2,125'), 3);
    expect(decimalPlaces('2'), 0);
  });

  testWidgets('shows the request data and loads the catalog', (tester) async {
    final server = FakeApi();
    await openScreen(tester, server, forRequest: request);
    expect(find.text('Portão de correr'), findsOneWidget);
    expect(find.text('Abertura de 3 m, aço e madeira escura.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'Referência: $requestId',
      ),
      findsOneWidget,
    );
    expect(server.calls, contains('GET /v1/materials'));
    expect(
      server.calls,
      contains('GET /v1/quote-requests/$requestId/pricing'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculates with the catalog cost; the server does the math', (
    tester,
  ) async {
    final server = FakeApi();
    await openScreen(tester, server, forRequest: request);
    await pickFromDropdown(tester, 'Metalon / m');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade (m)'),
      '2',
    );
    await tapButton(tester, 'Calcular preço');
    final cost = server.bodies['POST /v1/pricing/calculate']!['costs'][0];
    expect(cost['name'], 'Metalon');
    expect(cost['quantity'], 2);
    expect(cost['unitCost'], 25.5);
    await tester.ensureVisible(find.text('Preço sugerido'));
    expect(find.text('Preço sugerido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a catalog item by id and quantity, then reopens it', (
    tester,
  ) async {
    final server = FakeApi();
    await openScreen(tester, server, forRequest: request);
    await pickFromDropdown(tester, 'Metalon / m');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade (m)'),
      '2',
    );
    await tapButton(tester, 'Salvar precificação');

    final sent = server.bodies['POST /v1/quote-requests/$requestId/pricing']!;
    final cost = sent['costs'][0] as Map<String, dynamic>;
    expect(cost['materialId'], materialId);
    expect(cost['quantity'], 2);
    expect(cost.containsKey('unitCost'), isFalse); // o servidor decide o custo
    expect(sent['rates']['targetNetMarginRate'], 0);
    expect(find.textContaining('Precificação salva.'), findsOneWidget);
    expect(find.text('Preço sugerido'), findsOneWidget);

    // Fecha e abre de novo: precisa continuar lá.
    await openScreen(tester, server, forRequest: request);
    final quantity = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Quantidade (m)'),
    );
    expect(quantity.controller!.text, '2');
    expect(find.textContaining('Última precificação salva em'), findsOneWidget);
    expect(find.text('Preço sugerido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a manual item with unit and cost', (tester) async {
    final server = FakeApi();
    await openScreen(tester, server, forRequest: request);
    await pickFromDropdown(tester, 'Outro material (digitar)');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do material (ex.: Metalon)'),
      'Eletrodo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Unidade (ex.: metro, kg)'),
      'kg',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Custo por unidade (R\$)'),
      '12,50',
    );
    await tapButton(tester, 'Salvar precificação');
    final cost =
        server.bodies['POST /v1/quote-requests/$requestId/pricing']!['costs'][0];
    expect(cost['name'], 'Eletrodo');
    expect(cost['unit'], 'kg');
    expect(cost['quantity'], 1);
    expect(cost['unitCost'], 12.5);
    expect(cost.containsKey('materialId'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid quantity stays local and is not sent', (tester) async {
    final server = FakeApi();
    await openScreen(tester, server, forRequest: request);
    await pickFromDropdown(tester, 'Metalon / m');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade (m)'),
      '0',
    );
    await tapButton(tester, 'Salvar precificação');
    expect(find.text('A quantidade deve ser maior que zero.'), findsOneWidget);
    expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgetting to choose a material is caught locally', (
    tester,
  ) async {
    final server = FakeApi();
    await openScreen(tester, server, forRequest: request);
    await tapButton(tester, 'Calcular preço');
    expect(find.text('Escolha um material.'), findsOneWidget);
    expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the API error and lets the seller retry loading', (
    tester,
  ) async {
    final server = FakeApi()..materialsStatus = 500;
    await openScreen(tester, server, forRequest: request);
    expect(find.text('Falha ao carregar materiais.'), findsOneWidget);
    expect(find.text('Calcular preço'), findsNothing);

    server.materialsStatus = 200;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Calcular preço'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone simulation has no save button', (tester) async {
    final server = FakeApi();
    await openScreen(tester, server);
    expect(find.text('Calcular preço'), findsOneWidget);
    expect(find.text('Salvar precificação'), findsNothing);
    expect(server.calls, ['GET /v1/materials']);
    expect(tester.takeException(), isNull);
  });
}
