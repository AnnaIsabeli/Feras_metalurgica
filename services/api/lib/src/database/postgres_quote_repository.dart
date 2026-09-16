import 'package:fera_contracts/fera_contracts.dart';
import 'package:postgres/postgres.dart';
import '../quotes/quote_repository.dart';

class PostgresQuoteRepository implements QuoteRepository {
  PostgresQuoteRepository(this.pool);
  final Pool pool;

  @override
  Future<List<QuoteRequest>> list({String? buyerId}) async {
    final result = await pool.execute(
      Sql.named(
        'SELECT * FROM quote_requests '
        '${buyerId == null ? '' : 'WHERE buyer_id = @buyer'} '
        'ORDER BY created_at DESC, id DESC LIMIT 100',
      ),
      parameters: buyerId == null ? {} : {'buyer': buyerId},
    );
    return result.map((row) => _map(row.toColumnMap())).toList();
  }

  @override
  Future<QuoteRequest> create(QuoteRequest request) async {
    final result = await pool.execute(
      Sql.named('''
      INSERT INTO quote_requests (id, buyer_id, product, description, quantity, status, created_at)
      VALUES (@id, @buyer, @product, @description, @quantity, @status, @created)
      RETURNING *
    '''),
      parameters: {
        'id': request.id,
        'buyer': request.buyerId,
        'product': request.product,
        'description': request.description,
        'quantity': request.quantity,
        'status': request.status.name,
        'created': request.createdAt,
      },
    );
    return _map(result.first.toColumnMap());
  }

  QuoteRequest _map(Map<String, dynamic> row) => QuoteRequest(
    id: row['id'] as String,
    buyerId: row['buyer_id'] as String,
    product: row['product'] as String,
    description: row['description'] as String,
    quantity: row['quantity'] as int,
    status: RequestStatus.values.byName(row['status'] as String),
    createdAt: row['created_at'] as DateTime,
  );
}
