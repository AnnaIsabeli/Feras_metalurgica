import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import '../auth/google_identity_verifier.dart';
import '../auth/principal.dart';

class PostgresGoogleAccountRepository implements GoogleAccountRepository {
  PostgresGoogleAccountRepository(this.pool);
  final Pool pool;
  @override
  Future<Principal?> resolve({
    required String subject,
    required String email,
    required String name,
  }) async {
    // Subject is the stable Google identity. Do not link an existing account by email,
    // or accept role/approval supplied by the browser. Conflicting email fails closed.
    final result = await pool.execute(
      Sql.named('''
      INSERT INTO users (id, google_subject, email, display_name, role, seller_approved)
      VALUES (@id, @subject, @email, @name, 'buyer', false)
      ON CONFLICT (google_subject) DO UPDATE SET
        email = EXCLUDED.email, display_name = EXCLUDED.display_name
      RETURNING id, role, seller_approved
    '''),
      parameters: {
        'id': const Uuid().v4(),
        'subject': subject,
        'email': email,
        'name': name,
      },
    );
    final row = result.single.toColumnMap();
    return Principal(
      row['id'] as String,
      UserRole.values.byName(row['role'] as String),
      sellerApproved: row['seller_approved'] as bool,
    );
  }
}
