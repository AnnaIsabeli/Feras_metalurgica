import 'dart:io';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/database/postgres_pricing_repository.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:fera_api/src/quotes/pricing_service.dart';
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
    'state transitions are controlled, audited and reject stale updates',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final service = QuoteService(PostgresQuoteRepository(pool));
      final pricing = PricingService(PostgresPricingRepository(pool));
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
      await pricing.createQuote(seller, {
        'idempotencyKey': id,
        'customerName': 'Cliente teste',
        'product': 'Peça',
        'description': 'Controle de estado',
        'quantity': 2,
        'pricing': pricingPayload(),
      }, service);
      var quote = await service.changeStatus(seller, id, {
        'expectedStatus': 'pending',
        'status': 'approved',
      });
      expect(quote.status.name, 'approved');
      expect(quote.unitPriceCents, 30000);
      await expectLater(
        service.changeStatus(seller, id, {
          'expectedStatus': 'pending',
          'status': 'rejected',
        }),
        throwsA(anything),
      );
      await expectLater(
        pricing.save(seller, id, pricingPayload()),
        throwsA(anything),
      );
      await expectLater(
        service.changeStatus(
          const Principal(DevelopmentIdentityVerifier.buyerId, UserRole.buyer),
          id,
          {'expectedStatus': 'approved', 'status': 'inProduction'},
        ),
        throwsA(anything),
      );
      quote = await service.changeStatus(seller, id, {
        'expectedStatus': 'approved',
        'status': 'inProduction',
      });
      expect(quote.status.name, 'inProduction');
      quote = await service.changeStatus(seller, id, {
        'expectedStatus': 'inProduction',
        'status': 'completed',
      });
      expect(quote.status.name, 'completed');
      await expectLater(
        service.changeStatus(seller, id, {
          'expectedStatus': 'completed',
          'status': 'pending',
        }),
        throwsA(anything),
      );
      final events = await pool.execute(
        Sql.named(
          'SELECT to_status FROM quote_status_events WHERE quote_request_id=@id ORDER BY changed_at',
        ),
        parameters: {'id': id},
      );
      expect(events.map((r) => r[0]), [
        'approved',
        'inProduction',
        'completed',
      ]);
    },
    skip: url == null ? 'Set TEST_DATABASE_URL.' : false,
  );
  test(
    'customer and inclusive Brazilian dates filter without crossing buyer ownership',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final service = QuoteService(PostgresQuoteRepository(pool));
      final tag = const Uuid().v4();
      final ids = <String>[];
      addTearDown(() async {
        for (final id in ids) {
          await pool.execute(
            Sql.named('DELETE FROM quote_requests WHERE id=@id'),
            parameters: {'id': id},
          );
        }
      });
      for (final stamp in ['2026-11-19T02:30:00Z', '2026-11-19T03:00:00Z']) {
        final q = await service.create(seller, {
          'customerName': 'Cliente $tag',
          'product': 'Filtro',
          'description': 'Data Brasil',
          'quantity': 1,
        });
        ids.add(q.id);
        await pool.execute(
          Sql.named('UPDATE quote_requests SET created_at=@stamp WHERE id=@id'),
          parameters: {'id': q.id, 'stamp': DateTime.parse(stamp)},
        );
      }
      final items = await service.list(
        seller,
        filters: {'customer': tag, 'from': '2026-11-18', 'to': '2026-11-18'},
      );
      expect(items.map((q) => q.id), [ids.first]);
      expect(
        await service.list(
          const Principal(DevelopmentIdentityVerifier.buyerId, UserRole.buyer),
          filters: {'customer': tag},
        ),
        isEmpty,
      );
      expect(
        () => service.list(seller, filters: {'from': '2026-02-31'}),
        throwsA(anything),
      );
      expect(
        () => service.list(
          seller,
          filters: {'from': '2026-11-20', 'to': '2026-11-18'},
        ),
        throwsA(anything),
      );
    },
    skip: url == null ? 'Set TEST_DATABASE_URL.' : false,
  );
}
