import 'dart:convert';
import 'package:postgres/postgres.dart';
import '../documents/quote_document.dart';

class PostgresQuoteDocumentRepository implements QuoteDocumentRepository {
  PostgresQuoteDocumentRepository(this.pool);
  final Pool pool;

  @override
  Future<QuoteDocument?> find(String requestId, {String? pricingId}) async {
    // One statement reads one consistent revision and its frozen line items.
    // No catalog lookup, cost, rate or margin is exposed to the document renderer.
    final rows = await pool.execute(
      Sql.named('''
      WITH chosen AS (
        SELECT * FROM quote_pricings WHERE quote_request_id=@request
        ${pricingId == null ? '' : 'AND id=@pricing'}
        ORDER BY created_at DESC, id DESC LIMIT 1
      )
      SELECT q.id AS request_id, q.product, q.description, q.quantity,
        u.display_name AS customer_name, u.email AS customer_email,
        p.id AS pricing_id, p.created_at AS saved_at, p.total_price_cents,
        CASE WHEN jsonb_typeof(p.calculation_snapshot->'input'->'deliveryLeadTime')='string'
          THEN p.calculation_snapshot->'input'->>'deliveryLeadTime' END AS delivery_lead_time,
        COALESCE((SELECT jsonb_agg(jsonb_build_object(
          'name', i.material_name_snapshot, 'unit', i.unit_snapshot, 'quantity', i.quantity
        ) ORDER BY i.material_name_snapshot, i.unit_snapshot, i.id)
          FROM quote_pricing_items i WHERE i.quote_pricing_id=p.id), '[]'::jsonb) AS items
      FROM quote_requests q JOIN users u ON u.id=q.buyer_id
      JOIN chosen p ON p.quote_request_id=q.id
    '''),
      parameters: {'request': requestId, 'pricing': ?pricingId},
    );
    if (rows.isEmpty) return null;
    final data = rows.first.toColumnMap();
    final raw = data['items'];
    final items = (raw is String ? jsonDecode(raw) : raw) as List;
    return QuoteDocument(
      requestId: data['request_id'] as String,
      pricingId: data['pricing_id'] as String,
      savedAt: data['saved_at'] as DateTime,
      customerName: data['customer_name'] as String,
      customerEmail: data['customer_email'] as String,
      product: data['product'] as String,
      description: data['description'] as String,
      quantity: data['quantity'] as int,
      unitPriceCents: data['total_price_cents'] as int,
      deliveryLeadTime: data['delivery_lead_time'] as String?,
      items: items
          .map(
            (item) => QuoteDocumentItem(
              name: item['name'] as String,
              unit: item['unit'] as String,
              quantity: num.parse(item['quantity'].toString()),
            ),
          )
          .toList(),
    );
  }
}
