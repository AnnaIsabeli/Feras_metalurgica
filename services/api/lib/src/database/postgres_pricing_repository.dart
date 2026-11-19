import 'package:fera_contracts/fera_contracts.dart';
import '../core/api_error.dart';
import 'postgres_quote_repository.dart';
import 'dart:convert';
import 'package:postgres/postgres.dart';
import '../quotes/pricing_repository.dart';

class PostgresPricingRepository implements PricingRepository {
  PostgresPricingRepository(this.pool);
  final Pool pool;

  Map<String, dynamic> _material(Map<String, dynamic> row) => {
    'id': row['id'],
    'name': row['name'],
    'unit': row['unit'],
    'unitCost': double.parse(row['unit_cost'].toString()),
  };

  @override
  Future<List<Map<String, dynamic>>> materials() async {
    final rows = await pool.execute(
      'SELECT id, name, unit, unit_cost FROM materials WHERE active ORDER BY name, unit',
    );
    return rows.map((row) => _material(row.toColumnMap())).toList();
  }

  @override
  Future<Map<String, dynamic>?> material(String id) async {
    final rows = await pool.execute(
      Sql.named(
        'SELECT id, name, unit, unit_cost FROM materials WHERE id=@id AND active',
      ),
      parameters: {'id': id},
    );
    return rows.isEmpty ? null : _material(rows.first.toColumnMap());
  }

  Map<String, dynamic> _saved(Map<String, dynamic> row) {
    final raw = row['calculation_snapshot'];
    final snapshot = raw is String ? jsonDecode(raw) as Map : raw as Map?;
    return {
      'id': row['id'],
      'quoteRequestId': row['quote_request_id'],
      'createdBy': row['created_by'],
      'createdAt': (row['created_at'] as DateTime).toUtc().toIso8601String(),
      'totalPriceCents': row['total_price_cents'],
      'input': snapshot?['input'],
      'result': snapshot?['result'],
    };
  }

  @override
  Future<Map<String, dynamic>?> latest(String requestId) async {
    final rows = await pool.execute(
      Sql.named(
        'SELECT * FROM quote_pricings WHERE quote_request_id=@id '
        'ORDER BY created_at DESC, id DESC LIMIT 1',
      ),
      parameters: {'id': requestId},
    );
    return rows.isEmpty ? null : _saved(rows.first.toColumnMap());
  }

  @override
  Future<Map<String, dynamic>?> save({
    required String requestId,
    required String actorId,
    required Map<String, dynamic> input,
    required Map<String, dynamic> result,
    required int totalPriceCents,
    QuoteRequest? newRequest,
  }) => pool.runTx((session) async {
    if (newRequest != null) {
      await session.execute(
        Sql.named('''
        INSERT INTO quote_requests (id,buyer_id,created_by,customer_name,customer_contact,product,description,quantity,status,created_at)
        VALUES (@id,NULL,@actor,@name,@contact,@product,@description,@quantity,'pending',clock_timestamp())
        ON CONFLICT (id) DO NOTHING
      '''),
        parameters: {
          'id': requestId,
          'actor': actorId,
          'name': newRequest.customerName,
          'contact': newRequest.customerContact,
          'product': newRequest.product,
          'description': newRequest.description,
          'quantity': newRequest.quantity,
        },
      );
    }
    // Serialize revisions of one request and prevent deletion during save.
    final request = await session.execute(
      Sql.named('SELECT * FROM quote_requests WHERE id=@id FOR UPDATE'),
      parameters: {'id': requestId},
    );
    if (request.isEmpty) return null;
    final quote = request.single.toColumnMap();
    if (totalPriceCents > 9007199254740991 ~/ (quote['quantity'] as int)) {
      throw const ApiError(
        422,
        'quote_total_limit',
        'O valor total do orçamento excede o limite.',
      );
    }
    if (newRequest != null) {
      if (quote['created_by'] != actorId ||
          quote['customer_name'] != newRequest.customerName ||
          quote['customer_contact'] != newRequest.customerContact ||
          quote['product'] != newRequest.product ||
          quote['description'] != newRequest.description ||
          quote['quantity'] != newRequest.quantity) {
        throw const ApiError(
          409,
          'creation_key_conflict',
          'Esta tentativa já foi usada. Reabra o orçamento ou inicie outro.',
        );
      }
      final prior = await session.execute(
        Sql.named('''
        SELECT *, calculation_snapshot->'input' = CAST(@input AS jsonb) AS same_input
        FROM quote_pricings WHERE quote_request_id=@id ORDER BY created_at DESC,id DESC LIMIT 1
      '''),
        parameters: {'id': requestId, 'input': jsonEncode(input)},
      );
      if (prior.isNotEmpty) {
        final previous = prior.single.toColumnMap();
        if (previous['same_input'] != true) {
          throw const ApiError(
            409,
            'creation_key_conflict',
            'Este orçamento já foi salvo com outros valores. Reabra-o antes de alterar.',
          );
        }
        return {
          ..._saved(previous),
          'quote': PostgresQuoteRepository.mapRow(quote).toJson(),
        };
      }
    }
    if ([
      'approved',
      'inProduction',
      'completed',
      'cancelled',
    ].contains(quote['status'])) {
      throw const ApiError(
        409,
        'quote_locked',
        'Este orçamento não permite alterar valores no status atual.',
      );
    }

    final rows = await session.execute(
      Sql.named(
        'INSERT INTO quote_pricings '
        '(quote_request_id, created_by, total_price_cents, calculation_snapshot, created_at) '
        'VALUES (@request, @actor, @total, CAST(@snapshot AS jsonb), clock_timestamp()) RETURNING *',
      ),
      parameters: {
        'request': requestId,
        'actor': actorId,
        'total': totalPriceCents,
        'snapshot': jsonEncode({'input': input, 'result': result}),
      },
    );
    final row = rows.first.toColumnMap();
    for (final item in input['costs'] as List) {
      await session.execute(
        Sql.named(
          'INSERT INTO quote_pricing_items '
          '(quote_pricing_id, material_id, material_name_snapshot, unit_snapshot, '
          'quantity, unit_cost_snapshot, line_total_cents) '
          'VALUES (@pricing, @material, @name, @unit, @quantity, @cost, @total)',
        ),
        parameters: {
          'pricing': row['id'],
          'material': item['materialId'],
          'name': item['name'],
          'unit': item['unit'],
          'quantity': item['quantity'].toString(),
          'cost': item['unitCost'].toString(),
          'total': ((item['quantity'] as num) * (item['unitCost'] as num) * 100)
              .round(),
        },
      );
    }
    if (quote['status'] != 'pending') {
      await session.execute(
        Sql.named(
          "INSERT INTO quote_status_events(quote_request_id,from_status,to_status,changed_by) VALUES (@id,@old,'pending',@actor)",
        ),
        parameters: {'id': requestId, 'old': quote['status'], 'actor': actorId},
      );
    }
    await session.execute(
      Sql.named("UPDATE quote_requests SET status='pending' WHERE id=@id"),
      parameters: {'id': requestId},
    );
    return {
      ..._saved(row),
      if (newRequest != null)
        'quote': {
          ...PostgresQuoteRepository.mapRow(quote).toJson(),
          'status': 'pending',
        },
    };
  });
}
