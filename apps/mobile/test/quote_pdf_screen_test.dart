import 'dart:convert';
import 'package:fera_mobile/core/api_client.dart';
import 'package:fera_mobile/features/pricing/pricing_screen.dart';
import 'package:fera_mobile/features/pricing/quote_pdf_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'pricing_screen_test.dart' show request, pricingResult, requestId;

const revision = '33333333-3333-4333-8333-333333333333';

class FakePdfActions implements QuotePdfActions {
  int previews = 0;
  int downloads = 0;
  QuotePdfDownload? file;
  @override
  Future<bool> preview(QuotePdfDownload value) async {
    previews++;
    file = value;
    return true;
  }

  @override
  Future<bool> download(QuotePdfDownload value) async {
    downloads++;
    file = value;
    return true;
  }
}

class PdfScreenApi {
  bool hasSaved = true;
  int pdfStatus = 200;
  Map<String, dynamic>? posted;
  final pdfCalls = <Uri>[];
  Map<String, dynamic> snapshot() => {
    'id': revision,
    'createdAt': '2026-11-11T20:00:00Z',
    'result': pricingResult(100),
    'input':
        posted ??
        {
          'costs': [
            {
              'name': 'Metalon',
              'unit': 'm',
              'quantity': 6,
              'unitCost': 13.333333,
            },
          ],
          'rates': {for (final name in pricingRates.keys) name: 0},
          'deliveryLeadTime': '20 dias úteis',
        },
  };
  http.Response json(int status, Object data) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Future<http.Response> handle(http.Request r) async {
    expect(r.headers['authorization'], 'Bearer demo-seller');
    if (r.url.path == '/v1/materials') return json(200, {'items': []});
    if (r.url.path.endsWith('/pdf')) {
      pdfCalls.add(r.url);
      if (pdfStatus != 200)
        return json(pdfStatus, {
          'error': {
            'code': 'pricing_not_found',
            'message': 'Salve uma precificação antes de gerar o PDF.',
          },
        });
      return http.Response.bytes(
        utf8.encode('%PDF-1.7\ntest'),
        200,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition': 'attachment; filename="orcamento-teste.pdf"',
        },
      );
    }
    if (r.method == 'POST') {
      posted = jsonDecode(r.body) as Map<String, dynamic>;
      hasSaved = true;
      return json(201, snapshot());
    }
    return hasSaved
        ? json(200, snapshot())
        : json(404, {
            'error': {
              'code': 'pricing_not_found',
              'message': 'Sem precificação.',
            },
          });
  }
}

Future<void> openPdfScreen(
  WidgetTester tester,
  PdfScreenApi server,
  FakePdfActions actions,
) async {
  await tester.binding.setSurfaceSize(const Size(1100, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiClient(
    baseUrl: 'http://localhost',
    token: 'demo-seller',
    client: MockClient(server.handle),
  );
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: PricingScreen(api: api, request: request, pdfActions: actions),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saved quote previews and downloads its exact saved revision', (
    tester,
  ) async {
    final server = PdfScreenApi();
    final actions = FakePdfActions();
    await openPdfScreen(tester, server, actions);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Prazo de entrega (opcional)'),
          )
          .controller!
          .text,
      '20 dias úteis',
    );
    await press(tester, find.byKey(const Key('previewQuotePdf')));
    expect(actions.previews, 1);
    expect(server.pdfCalls.single.path, '/v1/quote-requests/$requestId/pdf');
    expect(server.pdfCalls.single.queryParameters['pricingId'], revision);
    await press(tester, find.byKey(const Key('downloadQuotePdf')));
    expect(actions.downloads, 1);
    expect(server.pdfCalls.last.queryParameters['download'], '1');
    expect(actions.file!.filename, 'orcamento-teste.pdf');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'requires saving and blocks stale PDF after edits until successful save',
    (tester) async {
      final server = PdfScreenApi()..hasSaved = false;
      final actions = FakePdfActions();
      await openPdfScreen(tester, server, actions);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('downloadQuotePdf')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      server.hasSaved = true;
      await openPdfScreen(tester, server, actions);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Prazo de entrega (opcional)'),
        '30 dias úteis',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('downloadQuotePdf')))
            .onPressed,
        isNull,
      );
      await press(tester, find.text('Salvar precificação'));
      expect(server.posted!['deliveryLeadTime'], '30 dias úteis');
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('downloadQuotePdf')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('PDF errors are shown and do not open native printing', (
    tester,
  ) async {
    final server = PdfScreenApi()..pdfStatus = 404;
    final actions = FakePdfActions();
    await openPdfScreen(tester, server, actions);
    await press(tester, find.byKey(const Key('downloadQuotePdf')));
    expect(
      find.text('Salve uma precificação antes de gerar o PDF.'),
      findsOneWidget,
    );
    expect(actions.downloads, 0);
    expect(actions.previews, 0);
    expect(tester.takeException(), isNull);
  });
}
