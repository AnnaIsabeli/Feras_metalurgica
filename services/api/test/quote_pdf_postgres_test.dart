import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/database/postgres_quote_document_repository.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/database/postgres_pricing_repository.dart';
import 'package:fera_api/src/documents/quote_pdf_renderer.dart';
import 'package:fera_api/src/documents/quote_pdf_service.dart';
import 'package:fera_api/src/quotes/pricing_service.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'saved_pricing_test.dart' show pricingPayload;
import '../tool/render_quote_pdf_example.dart' show exampleQuote;

class PdfFlowIdentity implements IdentityVerifier {
  PdfFlowIdentity(this.buyerId);
  final String buyerId;
  @override
  Future<Principal?> verify(String token) async => token == 'pdf-buyer'
      ? Principal(buyerId, UserRole.buyer)
      : DevelopmentIdentityVerifier().verify(token);
}

void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  test(
    'saved request -> pricing -> PDF; frozen items, price and delivery; exact revisions',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final buyerId = const Uuid().v4();
      final sample = exampleQuote();
      await pool.execute(
        Sql.named(
          "INSERT INTO users(id,email,display_name,role) VALUES (@id,@email,@name,'buyer')",
        ),
        parameters: {
          'id': buyerId,
          'email': 'pdf-$buyerId@example.invalid',
          'name': sample.customerName,
        },
      );
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM users WHERE id=@id'),
          parameters: {'id': buyerId},
        );
      });
      final repository = PostgresQuoteDocumentRepository(pool);
      final pricingService = PricingService(PostgresPricingRepository(pool));
      final handler = buildHandler(
        quotes: QuoteService(PostgresQuoteRepository(pool)),
        pricings: pricingService,
        pdfs: QuotePdfService(repository, await QuotePdfRenderer.load()),
        identity: PdfFlowIdentity(buyerId),
        checkDatabase: () async {},
        allowedOrigin: 'https://test.example.com',
      );
      Future<Response> post(
        String path,
        Map<String, dynamic> data, {
        String token = 'demo-seller',
      }) async => handler(
        Request(
          'POST',
          Uri.parse('http://localhost$path'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(data),
        ),
      );
      final created = await post('/v1/quote-requests', {
        'product': sample.product,
        'description': sample.description,
        'quantity': 1,
      }, token: 'pdf-buyer');
      expect(created.statusCode, 201);
      final quoteId = jsonDecode(await created.readAsString())['id'] as String;
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_pricings WHERE quote_request_id=@id'),
          parameters: {'id': quoteId},
        );
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id=@id'),
          parameters: {'id': quoteId},
        );
      });
      final material = await pool.execute(
        "INSERT INTO materials(name,unit,unit_cost) VALUES ('Metalon PDF ' || gen_random_uuid(),'m',13.333333) RETURNING id, name",
      );
      final materialId = material.first[0] as String;
      final materialName = material.first[1] as String;
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM materials WHERE id=@id'),
          parameters: {'id': materialId},
        );
      });
      const seller = Principal(
        DevelopmentIdentityVerifier.sellerId,
        UserRole.seller,
        sellerApproved: true,
      );
      final data = pricingPayload();
      data['costs'] = [
        {'materialId': materialId, 'quantity': 6},
        {
          'name': 'Chapa de aço galvanizado',
          'unit': 'm²',
          'quantity': 1.75,
          'unitCost': 85.123456,
        },
        {
          'name': 'Tinta esmalte PU',
          'unit': 'L',
          'quantity': .5,
          'unitCost': 72,
        },
      ];
      data['practicedPrice'] = 3870.45;
      data['deliveryLeadTime'] = sample.deliveryLeadTime;
      final saved = await post('/v1/quote-requests/$quoteId/pricing', data);
      expect(saved.statusCode, 201);
      final first =
          jsonDecode(await saved.readAsString()) as Map<String, dynamic>;
      await pool.execute(
        Sql.named(
          "UPDATE materials SET name='ALTERADO_NAO_DEVE_APARECER', unit_cost=9876.54321, active=false WHERE id=@id",
        ),
        parameters: {'id': materialId},
      );
      final loaded = (await repository.find(quoteId))!;
      expect(
        loaded.items.singleWhere((item) => item.name == materialName).quantity,
        6,
      );
      expect(loaded.totalPriceCents, 387045);
      expect(loaded.deliveryLeadTime, sample.deliveryLeadTime);
      final response = await handler(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/v1/quote-requests/$quoteId/pdf?download=1',
          ),
          headers: {'authorization': 'Bearer demo-seller'},
        ),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/pdf');
      expect(
        response.headers['content-disposition'],
        startsWith('attachment;'),
      );
      final pdfBytes = await response.read().expand((chunk) => chunk).toList();
      final target = Platform.environment['PDF_TEST_OUTPUT_DIRECTORY'];
      if (target != null) {
        await Directory(target).create(recursive: true);
        await File('$target/orcamento-persistido.pdf').writeAsBytes(pdfBytes);
      }
      final second = await pricingService.save(
        seller,
        quoteId,
        pricingPayload(),
      );
      expect((await repository.find(quoteId))!.pricingId, second['id']);
      final old = (await repository.find(
        quoteId,
        pricingId: first['id'] as String,
      ))!;
      expect(old.totalPriceCents, 387045);
      expect(old.deliveryLeadTime, sample.deliveryLeadTime);
      expect(
        await repository.find(
          'ffffffff-ffff-4fff-8fff-ffffffffffff',
          pricingId: first['id'] as String,
        ),
        isNull,
      );
      expect((await repository.find(quoteId))!.deliveryLeadTime, isNull);
    },
    skip: url == null
        ? 'Set TEST_DATABASE_URL with test migrations and seed.'
        : false,
  );
}
