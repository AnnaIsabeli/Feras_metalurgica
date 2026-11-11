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
  }) => pool.runTx((session) async {
    // Serialize revisions of one request and prevent deletion during save.
    final request = await session.execute(
      Sql.named('SELECT id FROM quote_requests WHERE id=@id FOR UPDATE'),
      parameters: {'id': requestId},
    );
    if (request.isEmpty) return null;
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
    return _saved(row);
  });
}
