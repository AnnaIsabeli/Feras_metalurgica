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
}
