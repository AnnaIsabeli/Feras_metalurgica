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
    return result.map((row) => mapRow(row.toColumnMap())).toList();
  }

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
    customerName: row['customer_name'] as String?,
    customerContact: row['customer_contact'] as String?,
    product: row['product'] as String,
    description: row['description'] as String,
    quantity: row['quantity'] as int,
    status: RequestStatus.values.byName(row['status'] as String),
    createdAt: row['created_at'] as DateTime,
  );
}
