import 'dart:convert';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/documents/quote_document.dart';
import 'package:fera_api/src/documents/quote_pdf_renderer.dart';
import 'package:fera_api/src/documents/quote_pdf_service.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import '../tool/render_quote_pdf_example.dart' show exampleQuote;
import 'app_test.dart' show MemoryQuotes;

class MemoryDocuments implements QuoteDocumentRepository {
  QuoteDocument? document = exampleQuote();
  int reads = 0;
  @override
  Future<QuoteDocument?> find(String id, {String? pricingId}) async {
    reads++;
    if (document?.requestId != id ||
        (pricingId != null && document?.pricingId != pricingId)) {
      return null;
    }
    return document;
  }
}

class PdfIdentity implements IdentityVerifier {
  @override
  Future<Principal?> verify(String token) async => token == 'unapproved'
      ? const Principal('00000000-0000-4000-8000-000000000003', UserRole.seller)
      : DevelopmentIdentityVerifier().verify(token);
}

void main() {
  late QuotePdfRenderer renderer;
  late MemoryDocuments documents;
  late Handler handler;
  setUpAll(() async {
    renderer = await QuotePdfRenderer.load();
  });
  setUp(() {
    documents = MemoryDocuments();
    handler = buildHandler(
      quotes: QuoteService(MemoryQuotes()),
      pdfs: QuotePdfService(documents, renderer),
      identity: PdfIdentity(),
      checkDatabase: () async {},
      allowedOrigin: 'https://dev.example.com',
    );
  });
  Future<Response> get({
    String? token = 'demo-seller',
    String suffix = '',
    String id = '12345678-1234-4234-8234-123456789012',
    String? origin,
  }) async => handler(
    Request(
      'GET',
      Uri.parse('http://localhost/v1/quote-requests/$id/pdf$suffix'),
      headers: {
        if (token != null) 'authorization': 'Bearer $token',
        'origin': ?origin,
      },
    ),
  );
  test(
    'seller previews and downloads a real PDF with private headers',
    () async {
      final preview = await get(origin: 'https://dev.example.com');
      expect(preview.statusCode, 200);
      expect(preview.headers['content-type'], 'application/pdf');
      expect(preview.headers['content-disposition'], startsWith('inline;'));
      expect(preview.headers['cache-control'], 'private, no-store');
      expect(preview.headers['x-content-type-options'], 'nosniff');
      expect(
        preview.headers['access-control-expose-headers'],
        'Content-Disposition',
      );
      final bytes = await preview.read().expand((chunk) => chunk).toList();
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(10000));
      final download = await get(suffix: '?download=1');
      expect(download.statusCode, 200);
      expect(
        download.headers['content-disposition'],
        startsWith('attachment; filename="orcamento-'),
      );
      expect(
        download.headers['content-disposition'],
        contains(exampleQuote().pricingId),
      );
    },
  );
  test(
    'anonymous, buyers, unapproved sellers and wrong origins cannot read PDF',
    () async {
      expect((await get(token: null)).statusCode, 401);
      expect((await get(token: 'demo-buyer')).statusCode, 403);
      expect(
        (await get(token: 'demo-buyer', suffix: '?download=bad')).statusCode,
        403,
      );
      expect((await get(token: 'unapproved')).statusCode, 403);
      expect((await get(origin: 'https://other.example.com')).statusCode, 403);
      expect(documents.reads, 0);
    },
  );
  test(
    'invalid IDs and download options fail before accessing repository',
    () async {
      expect((await get(id: 'invalid')).statusCode, 422);
      expect((await get(suffix: '?pricingId=invalid')).statusCode, 422);
      expect((await get(suffix: '?download=maybe')).statusCode, 422);
      expect(documents.reads, 0);
    },
  );
  test(
    'requires a saved pricing and scopes an explicit revision to its request',
    () async {
      final missing = await get(
        suffix: '?pricingId=00000000-0000-4000-8000-000000000099',
      );
      expect(missing.statusCode, 404);
      documents.document = null;
      final response = await get();
      expect(response.statusCode, 404);
      final body = jsonDecode(await response.readAsString());
      expect(body['error']['code'], 'pricing_not_found');
    },
  );
  test(
    'supports maximum description and one hundred long items across pages',
    () async {
      final bytes = await renderer.render(exampleQuote(stress: true));
      expect(bytes.length, greaterThan(10000));
    },
  );
  test(
    'formats persisted cents and fractional quantities without recalculating price',
    () {
      expect(QuotePdfRenderer.money(387045), 'R\$ 3.870,45');
      expect(QuotePdfRenderer.money(5), 'R\$ 0,05');
      expect(QuotePdfRenderer.money(100), 'R\$ 1,00');
      expect(QuotePdfRenderer.amount(6), '6');
      expect(QuotePdfRenderer.amount(1.75), '1,75');
      expect(QuotePdfRenderer.amount(.125), '0,125');
    },
  );
  test('incomplete pricing and unsupported glyphs fail explicitly', () async {
    documents.document = exampleQuote(empty: true);
    expect((await get()).statusCode, 409);
    documents.document = exampleQuote(unsupported: true);
    final response = await get();
    expect(response.statusCode, 422);
    expect(
      jsonDecode(await response.readAsString())['error']['code'],
      'unsupported_pdf_character',
    );
  });
}
