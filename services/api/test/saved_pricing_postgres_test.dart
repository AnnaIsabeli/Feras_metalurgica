import 'dart:io';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/database/postgres_pricing_repository.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/quotes/pricing_service.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'saved_pricing_test.dart' show pricingPayload;

void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  test(
    'atomic save, snapshots, revisions and persistence across pools',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final quote = await QuoteService(PostgresQuoteRepository(pool)).create(
        const Principal(DevelopmentIdentityVerifier.buyerId, UserRole.buyer),
        {
          'product': 'Integração orçamento',
          'description': 'Snapshot',
          'quantity': 1,
        },
      );
      final material = await pool.execute(
        "INSERT INTO materials(name, unit, unit_cost) VALUES ('Snapshot test ' || gen_random_uuid(), 'kg', 12.345678) RETURNING id",
      );
      final materialId = material.first[0] as String;
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_pricings WHERE quote_request_id=@id'),
          parameters: {'id': quote.id},
        );
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id=@id'),
          parameters: {'id': quote.id},
        );
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
      final repository = PostgresPricingRepository(pool);
      final service = PricingService(repository);
      final data = pricingPayload();
      data['costs'][0]['materialId'] = materialId;
      final first = await service.save(seller, quote.id, data);
      expect(first['totalPriceCents'], 30000);
      expect(first['result']['cmv'], closeTo(24.691356, .00000001));
      final items = await pool.execute(
        Sql.named(
          'SELECT * FROM quote_pricing_items WHERE quote_pricing_id=@id',
        ),
        parameters: {'id': first['id']},
      );
      expect(items.length, 1);
      expect(items.first.toColumnMap()['line_total_cents'], 2469);
      await pool.execute(
        Sql.named(
          'UPDATE materials SET unit_cost=999, active=false WHERE id=@id',
        ),
        parameters: {'id': materialId},
      );
      final reopenedPool = Pool.withUrl(url);
      addTearDown(reopenedPool.close);
      expect(
        await PricingService(
          PostgresPricingRepository(reopenedPool),
        ).latest(seller, quote.id),
        first,
      );
      final second = await service.save(seller, quote.id, pricingPayload());
      expect(second['id'], isNot(first['id']));
      expect((await service.latest(seller, quote.id))['id'], second['id']);
      // Force an item failure after the header insert: the whole transaction rolls back.
      final invalid = pricingPayload();
      invalid['costs'][0]['unit'] = '';
      await expectLater(
        repository.save(
          requestId: quote.id,
          actorId: seller.id,
          input: invalid,
          result: {},
          totalPriceCents: 100,
        ),
        throwsA(isA<Exception>()),
      );
      final count = await pool.execute(
        Sql.named(
          'SELECT count(*) FROM quote_pricings WHERE quote_request_id=@id',
        ),
        parameters: {'id': quote.id},
      );
      expect(count.first[0], 2);
      final status = await pool.execute(
        Sql.named('SELECT status FROM quote_requests WHERE id=@id'),
        parameters: {'id': quote.id},
      );
      expect(status.first[0], 'received');
    },
    skip: url == null
        ? 'Set TEST_DATABASE_URL with migrations and development seed.'
        : false,
  );
}
