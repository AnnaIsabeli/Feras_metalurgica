import 'package:fera_contracts/fera_contracts.dart';
import 'package:postgres/postgres.dart';
import '../quotes/quote_repository.dart';

class PostgresQuoteRepository implements QuoteRepository {
  PostgresQuoteRepository(this.pool);
  final Pool pool;

  @override
  Future<List<QuoteRequest>> list({
    String? buyerId,
    String? customer,
    String? from,
    String? to,
    String? status,
  }) async {
    final escaped = customer
        ?.replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final result = await pool.execute(
      Sql.named('''
      SELECT q.*, p.total_price_cents AS unit_price_cents, p.id AS latest_pricing_id, COALESCE(q.customer_name,u.display_name) AS resolved_customer
      FROM quote_requests q LEFT JOIN users u ON u.id=q.buyer_id
      LEFT JOIN LATERAL (SELECT id,total_price_cents FROM quote_pricings WHERE quote_request_id=q.id ORDER BY created_at DESC,id DESC LIMIT 1) p ON TRUE
      WHERE TRUE
      ${buyerId == null ? '' : 'AND q.buyer_id=@buyer'}
      ${customer == null ? '' : "AND COALESCE(q.customer_name,u.display_name,'') ILIKE @customer"}
      ${from == null ? '' : "AND q.created_at >= (CAST(@from AS date)::timestamp AT TIME ZONE 'America/Sao_Paulo')"}
      ${to == null ? '' : "AND q.created_at < ((CAST(@to AS date) + INTERVAL '1 day') AT TIME ZONE 'America/Sao_Paulo')"}
      ${status == null ? '' : 'AND q.status=@status'}
      ORDER BY q.created_at DESC,q.id DESC LIMIT 100
    '''),
      parameters: {
        'buyer': ?buyerId,
        'customer': ?(escaped == null ? null : '%$escaped%'),
        'from': ?from,
        'to': ?to,
        'status': ?status,
      },
    );
    return result.map((row) => mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<QuoteRequest?> find(String id) async {
    final rows = await pool.execute(
      Sql.named(
        "SELECT q.*,p.total_price_cents AS unit_price_cents,p.id AS latest_pricing_id,COALESCE(q.customer_name,u.display_name) AS resolved_customer FROM quote_requests q LEFT JOIN users u ON u.id=q.buyer_id LEFT JOIN LATERAL (SELECT id,total_price_cents FROM quote_pricings WHERE quote_request_id=q.id ORDER BY created_at DESC,id DESC LIMIT 1) p ON TRUE WHERE q.id=@id",
      ),
      parameters: {'id': id},
    );
    return rows.isEmpty ? null : mapRow(rows.single.toColumnMap());
  }

  @override
  Future<QuoteRequest?> transition({
    required String id,
    required String expected,
    required String target,
    required String actorId,
  }) => pool.runTx((session) async {
    final rows = await session.execute(
      Sql.named(
        'UPDATE quote_requests SET status=@target WHERE id=@id AND status=@expected RETURNING *',
      ),
      parameters: {'id': id, 'target': target, 'expected': expected},
    );
    if (rows.isEmpty) return null;
    await session.execute(
      Sql.named(
        'INSERT INTO quote_status_events(quote_request_id,from_status,to_status,changed_by) VALUES (@id,@old,@new,@actor)',
      ),
      parameters: {'id': id, 'old': expected, 'new': target, 'actor': actorId},
    );
    return mapRow(rows.single.toColumnMap());
  });

  @override
  Future<QuoteRequest> create(QuoteRequest request) async {
    final result = await pool.execute(
      Sql.named('''
      INSERT INTO quote_requests (id, buyer_id, product, description, quantity, status, created_at, created_by, customer_name, customer_contact)
      VALUES (@id, @buyer, @product, @description, @quantity, @status, @created, @creator, @customerName, @customerContact)
      RETURNING *
    '''),
      parameters: {
        'id': request.id,
        'buyer': request.buyerId,
        'creator': request.createdBy,
        'customerName': request.customerName,
        'customerContact': request.customerContact,
        'product': request.product,
        'description': request.description,
        'quantity': request.quantity,
        'status': request.status.name,
        'created': request.createdAt,
      },
    );
    return mapRow(result.first.toColumnMap());
  }

  static QuoteRequest mapRow(Map<String, dynamic> row) => QuoteRequest(
    id: row['id'] as String,
    buyerId: row['buyer_id'] as String?,
    createdBy: row['created_by'] as String,
    customerName: (row['customer_name'] ?? row['resolved_customer']) as String?,
    customerContact: row['customer_contact'] as String?,
    unitPriceCents: row['unit_price_cents'] as int?,
    pricingId: row['latest_pricing_id'] as String?,
    product: row['product'] as String,
    description: row['description'] as String,
    quantity: row['quantity'] as int,
    status: RequestStatus.values.byName(row['status'] as String),
    createdAt: row['created_at'] as DateTime,
  );
}
