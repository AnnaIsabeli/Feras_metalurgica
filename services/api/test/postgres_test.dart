import 'dart:io';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  test(
    'persists request in PostgreSQL and retrieves by buyer',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final service = QuoteService(PostgresQuoteRepository(pool));
      const buyer = Principal(
        DevelopmentIdentityVerifier.buyerId,
        UserRole.buyer,
      );
      final created = await service.create(buyer, {
        'product': 'Teste integração',
        'description': 'Persistência real',
        'quantity': 2,
      });
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id=@id'),
          parameters: {'id': created.id},
        );
      });
      expect(
        (await service.list(
          buyer,
        )).any((q) => q.id == created.id && q.quantity == 2),
        isTrue,
      );
      expect(
        await service.list(
          const Principal(
            '00000000-0000-4000-8000-000000000099',
            UserRole.buyer,
          ),
        ),
        isEmpty,
      );
    },
    skip: url == null
        ? 'Set TEST_DATABASE_URL with migrations and development seed applied.'
        : false,
  );
  test(
    'seller persists customer without creating a users account',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final service = QuoteService(PostgresQuoteRepository(pool));
      final before = (await pool.execute(
        'SELECT count(*) FROM users',
      )).first.first;
      const seller = Principal(
        DevelopmentIdentityVerifier.sellerId,
        UserRole.seller,
        sellerApproved: true,
      );
      final created = await service.create(seller, {
        'product': 'Pedido do WhatsApp',
        'description': 'Atendimento pela equipe',
        'quantity': 2,
        'customerName': 'Cliente de teste',
        'customerContact': 'Contato de teste',
      });
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id=@id'),
          parameters: {'id': created.id},
        );
      });
      expect(created.buyerId, isNull);
      expect(created.createdBy, seller.id);
      final saved = (await service.list(
        seller,
      )).singleWhere((item) => item.id == created.id);
      expect(saved.customerName, 'Cliente de teste');
      expect(saved.customerContact, 'Contato de teste');
      expect(
        (await pool.execute('SELECT count(*) FROM users')).first.first,
        before,
      );
      expect(
        (await service.list(
          const Principal(DevelopmentIdentityVerifier.buyerId, UserRole.buyer),
        )).any((item) => item.id == created.id),
        isFalse,
      );
    },
    skip: url == null ? 'Set TEST_DATABASE_URL.' : false,
  );
}
