import 'dart:io';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/database/postgres_pricing_repository.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/quotes/pricing_service.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'saved_pricing_test.dart' show pricingPayload;

void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  const seller = Principal(
    DevelopmentIdentityVerifier.sellerId,
    UserRole.seller,
    sellerApproved: true,
  );
  test(
    'creates quote and pricing together and retries do not duplicate either',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final id = const Uuid().v4();
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_pricings WHERE quote_request_id=@id'),
          parameters: {'id': id},
        );
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id=@id'),
          parameters: {'id': id},
        );
      });
      final service = PricingService(PostgresPricingRepository(pool));
      final quotes = QuoteService(PostgresQuoteRepository(pool));
      final payload = <String, dynamic>{
        'idempotencyKey': id,
        'customerName': 'Cliente WhatsApp',
        'customerContact': 'Contato informado',
        'product': 'Portão',
        'description': 'Pedido completo',
        'quantity': 3,
        'pricing': pricingPayload(),
      };
      final results = await Future.wait([
        service.createQuote(seller, payload, quotes),
        service.createQuote(seller, payload, quotes),
      ]);
      expect(results[0]['id'], results[1]['id']);
      expect(results[0]['quoteRequestId'], id);
      expect(results[0]['quote']['status'], 'pending');
      expect(results[0]['quote']['buyerId'], isNull);
      expect(results[0]['quote']['customerName'], 'Cliente WhatsApp');
      expect(
        (await pool.execute(
          Sql.named(
            'SELECT count(*) FROM quote_pricings WHERE quote_request_id=@id',
          ),
          parameters: {'id': id},
        )).single.single,
        1,
      );
      expect((await service.latest(seller, id))['id'], results[0]['id']);
      await expectLater(
        service.createQuote(seller, {...payload, 'quantity': 5}, quotes),
        throwsA(anything),
      );
      await expectLater(
        service.createQuote(
          const Principal(DevelopmentIdentityVerifier.buyerId, UserRole.buyer),
          payload,
          quotes,
        ),
        throwsA(anything),
      );
    },
    skip: url == null ? 'Set TEST_DATABASE_URL.' : false,
  );

  test(
    'database failure rolls back quote, pricing and items',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final quotes = QuoteService(PostgresQuoteRepository(pool));
      final request = quotes.prepare(seller, {
        'customerName': 'Cliente teste',
        'product': 'Peça',
        'description': 'Rollback',
        'quantity': 1,
      });
      await expectLater(
        PostgresPricingRepository(pool).save(
          requestId: request.id,
          actorId: seller.id,
          newRequest: request,
          input: {
            'costs': [
              {'name': 'Inválido', 'unit': 'kg', 'quantity': 1, 'unitCost': -1},
            ],
          },
          result: {},
          totalPriceCents: 10,
        ),
        throwsA(anything),
      );
      expect(
        (await pool.execute(
          Sql.named('SELECT count(*) FROM quote_requests WHERE id=@id'),
          parameters: {'id': request.id},
        )).single.single,
        0,
      );
      expect(
        (await pool.execute(
          Sql.named(
            'SELECT count(*) FROM quote_pricings WHERE quote_request_id=@id',
          ),
          parameters: {'id': request.id},
        )).single.single,
        0,
      );
    },
    skip: url == null ? 'Set TEST_DATABASE_URL.' : false,
  );
}
