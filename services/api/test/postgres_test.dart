import 'dart:io';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/database/postgres_material_repository.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/materials/material_repository.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

/// Exige TEST_DATABASE_URL com as migrações 001, 002 e 003 e o seed
/// development.sql aplicados. Sem a variável, os testes são ignorados
/// (não aprovados).
void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  final skip = url == null
      ? 'Set TEST_DATABASE_URL with migrations and development seed applied.'
      : false;

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
    skip: skip,
  );

  test(
    'cliente B não lê nem baixa PDF de solicitação do cliente A (PostgreSQL)',
    () async {
      final pool = Pool.withUrl(url!);
      addTearDown(pool.close);
      final service = QuoteService(PostgresQuoteRepository(pool));
      const owner = Principal(
        DevelopmentIdentityVerifier.buyerId,
        UserRole.buyer,
      );
      const other = Principal(
        DevelopmentIdentityVerifier.otherBuyerId,
        UserRole.buyer,
      );
      const admin = Principal(DevelopmentIdentityVerifier.adminId, UserRole.admin);
      final created = await service.create(owner, {
        'product': 'Isolamento',
        'description': 'Somente do dono',
        'quantity': 1,
      });
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id=@id'),
          parameters: {'id': created.id},
        );
      });
      expect((await service.get(owner, created.id)).id, created.id);
      expect((await service.get(admin, created.id)).id, created.id);
      await expectLater(service.get(other, created.id), throwsA(anything));
      await expectLater(service.authorizePdf(other, created.id), throwsA(anything));
      expect(await service.list(other), isEmpty);
    },
    skip: skip,
  );

  group('catálogo de materiais (PostgreSQL)', () {
    late Pool pool;
    late PostgresMaterialRepository repository;
    final created = <String>[];

    setUp(() {
      if (url == null) return;
      pool = Pool.withUrl(url);
      repository = PostgresMaterialRepository(pool);
    });
    tearDown(() async {
      if (url == null) return;
      for (final id in created) {
        await pool.execute(
          Sql.named('DELETE FROM quote_pricing_items WHERE material_id = @id'),
          parameters: {'id': id},
        );
        await pool.execute(
          Sql.named('DELETE FROM materials WHERE id = @id'),
          parameters: {'id': id},
        );
      }
      created.clear();
      await pool.close();
    });

    Future<String> make(String name, String unit, String cost) async {
      final m = await repository.create(name: name, unit: unit, unitCost: cost);
      created.add(m.id);
      return m.id;
    }

    test('cadastra, edita, desativa e recupera mantendo o custo exato', () async {
      final tag = DateTime.now().microsecondsSinceEpoch;
      final id = await make('Teste KAN $tag', 'metro', '13.333333');
      var m = (await repository.find(id))!;
      expect(m.unitCost, '13.333333');
      expect(m.active, isTrue);

      await repository.update(id, name: 'Teste KAN $tag B', unitCost: '14.5');
      m = (await repository.find(id))!;
      expect(m.name, 'Teste KAN $tag B');
      expect(m.unitCost, '14.500000');

      await repository.update(id, active: false);
      m = (await repository.find(id))!;
      expect(m.active, isFalse);
      final active = await repository.list(
        query: 'Teste KAN $tag',
        status: MaterialStatus.active,
      );
      final inactive = await repository.list(
        query: 'Teste KAN $tag',
        status: MaterialStatus.inactive,
      );
      expect(active, isEmpty);
      expect(inactive.map((x) => x.id), contains(id));
    }, skip: skip);

    test('duplicado (nome + unidade, sem diferenciar caixa) lança exceção', () async {
      final tag = DateTime.now().microsecondsSinceEpoch;
      await make('Duplicado $tag', 'kg', '1');
      await expectLater(
        repository.create(name: 'DUPLICADO $tag', unit: 'KG', unitCost: '2'),
        throwsA(isA<DuplicateMaterialException>()),
      );
    }, skip: skip);

    test('restrições do banco rejeitam custo negativo e nome em branco', () async {
      await expectLater(
        repository.create(name: 'Negativo', unit: 'kg', unitCost: '-1'),
        throwsA(anything),
      );
      await expectLater(
        repository.create(name: '   ', unit: 'kg', unitCost: '1'),
        throwsA(anything),
      );
    }, skip: skip);

    test('busca trata % e _ como texto, não como curinga', () async {
      final tag = DateTime.now().microsecondsSinceEpoch;
      final plain = await make('Busca $tag A', 'm', '1');
      final percent = await make('Busca $tag 50%', 'm', '1');
      final result = await repository.list(query: '%');
      final ids = result.map((x) => x.id).toList();
      expect(ids, contains(percent));
      expect(ids, isNot(contains(plain)));
    }, skip: skip);

    test('editar ou desativar material NÃO altera o custo de orçamentos antigos', () async {
      final tag = DateTime.now().microsecondsSinceEpoch;
      final materialId = await make('Histórico $tag', 'metro', '10');
      final quote = await pool.execute(
        Sql.named(
          'INSERT INTO quote_requests (id, buyer_id, product, description, quantity) '
          'VALUES (gen_random_uuid(), @buyer, @p, @d, 1) RETURNING id',
        ),
        parameters: {
          'buyer': DevelopmentIdentityVerifier.buyerId,
          'p': 'Histórico',
          'd': 'Teste de snapshot',
        },
      );
      final quoteId = quote.first.toColumnMap()['id'] as String;
      addTearDown(() async {
        await pool.execute(
          Sql.named('DELETE FROM quote_pricings WHERE quote_request_id = @id'),
          parameters: {'id': quoteId},
        );
        await pool.execute(
          Sql.named('DELETE FROM quote_requests WHERE id = @id'),
          parameters: {'id': quoteId},
        );
      });
      final pricing = await pool.execute(
        Sql.named(
          'INSERT INTO quote_pricings (quote_request_id, created_by, total_price_cents) '
          'VALUES (@q, @u, 2000) RETURNING id',
        ),
        parameters: {'q': quoteId, 'u': DevelopmentIdentityVerifier.adminId},
      );
      final pricingId = pricing.first.toColumnMap()['id'] as String;
      await pool.execute(
        Sql.named(
          'INSERT INTO quote_pricing_items (quote_pricing_id, material_id, '
          'material_name_snapshot, unit_snapshot, quantity, unit_cost_snapshot, line_total_cents) '
          'VALUES (@p, @m, @n, @u, 2, @c::text::numeric, 2000)',
        ),
        parameters: {
          'p': pricingId,
          'm': materialId,
          'n': 'Histórico $tag',
          'u': 'metro',
          'c': '10',
        },
      );

      // Altera custo, nome, unidade e desativa o material.
      await repository.update(
        materialId,
        name: 'Renomeado $tag',
        unit: 'barra',
        unitCost: '99.999999',
        active: false,
      );

      final item = (await pool.execute(
        Sql.named(
          'SELECT material_name_snapshot, unit_snapshot, '
          'unit_cost_snapshot::text AS cost, line_total_cents::text AS line '
          'FROM quote_pricing_items WHERE quote_pricing_id = @p',
        ),
        parameters: {'p': pricingId},
      )).first.toColumnMap();
      expect(item['material_name_snapshot'], 'Histórico $tag');
      expect(item['unit_snapshot'], 'metro');
      expect(item['cost'], '10.000000');
      expect(item['line'], '2000');
      final total = (await pool.execute(
        Sql.named('SELECT total_price_cents::text AS t FROM quote_pricings WHERE id = @p'),
        parameters: {'p': pricingId},
      )).first.toColumnMap();
      expect(total['t'], '2000');
    }, skip: skip);
  });
}
