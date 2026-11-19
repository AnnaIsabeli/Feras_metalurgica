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
  }) => pool.runTx((tx) async {
    // Only a verified subject identifies an account. Invitations are explicit
    // administrator authorization, never automatic account linking by email.
    final result = await tx.execute(
      Sql.named(
        '''INSERT INTO users(id,google_subject,email,display_name,role,seller_approved)
      VALUES(@id,@subject,@email,@name,'buyer',false) ON CONFLICT(google_subject) DO UPDATE SET email=EXCLUDED.email,display_name=EXCLUDED.display_name RETURNING id''',
      ),
      parameters: {
        'id': const Uuid().v4(),
        'subject': subject,
        'email': email,
        'name': name,
      },
    );
    final id = result.single.first as String;
    final invites = await tx.execute(
      Sql.named(
        '''SELECT i.* FROM access_invitations i WHERE i.email=lower(@email) AND i.role='seller' AND i.accepted_by IS NULL AND i.expires_at>now()
      AND EXISTS(SELECT 1 FROM admin_accounts a WHERE a.user_id=i.invited_by AND a.enabled AND a.activated_at IS NOT NULL) FOR UPDATE''',
      ),
      parameters: {'email': email},
    );
    if (invites.isNotEmpty) {
      final invitation = invites.single.toColumnMap();
      await tx.execute(
        Sql.named(
          "UPDATE users SET role='seller',seller_approved=true WHERE id=@id",
        ),
        parameters: {'id': id},
      );
      await tx.execute(
        Sql.named(
          "UPDATE access_invitations SET accepted_by=@id WHERE email=lower(@email) AND role='seller'",
        ),
        parameters: {'id': id, 'email': email},
      );
      await tx.execute(
        Sql.named(
          "INSERT INTO admin_audit_events(id,actor_id,target_id,action,reason) VALUES(@event,@actor,@target,'seller_approved',@reason)",
        ),
        parameters: {
          'event': const Uuid().v4(),
          'actor': invitation['invited_by'],
          'target': id,
          'reason': invitation['reason'],
        },
      );
    }
    final current = (await tx.execute(
      Sql.named('''SELECT u.id,u.role,u.seller_approved,
      (EXISTS(SELECT 1 FROM admin_accounts a WHERE a.user_id=u.id AND a.enabled) OR EXISTS(
        SELECT 1 FROM access_invitations i WHERE i.email=lower(u.email) AND i.role='admin' AND i.expires_at>now() AND (i.accepted_by IS NULL OR i.accepted_by=u.id)
        AND (i.invited_by IS NULL OR EXISTS(SELECT 1 FROM admin_accounts a WHERE a.user_id=i.invited_by AND a.enabled AND a.activated_at IS NOT NULL)))) AS admin_eligible
      FROM users u WHERE u.id=@id'''),
      parameters: {'id': id},
    )).single.toColumnMap();
    return Principal(
      id,
      UserRole.values.byName(current['role'] as String),
      sellerApproved: current['seller_approved'] as bool,
      adminEligible: current['admin_eligible'] as bool,
    );
  });
}
