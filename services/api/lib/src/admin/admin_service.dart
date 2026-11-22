import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import '../auth/principal.dart';
import '../core/api_error.dart';
import 'admin_crypto.dart';

class AdminService {
  AdminService(this.pool, this.crypto, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Pool pool;
  final AdminCrypto crypto;
  final DateTime Function() now;
  static const _uuid = Uuid();
  void eligible(Principal actor) {
    if (!actor.googleVerified || !actor.adminEligible) {
      throw const ApiError(
        403,
        'admin_required',
        'Acesso administrativo não autorizado.',
      );
    }
  }

  void fresh(Principal actor) {
    eligible(actor);
    final issued = actor.tokenIssuedAt;
    final age = issued == null
        ? const Duration(days: 1)
        : now().toUtc().difference(issued);
    if (age.isNegative || age > const Duration(minutes: 5)) {
      throw const ApiError(
        401,
        'admin_login_required',
        'Saia e entre novamente com Google para acessar a administração.',
      );
    }
  }

  Future<void> _audit(
    Session tx,
    String actor,
    String action, {
    String? target,
    String? reason,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? command,
    String? hash,
  }) async {
    await tx.execute(
      Sql.named(
        '''INSERT INTO admin_audit_events(id,actor_id,target_id,action,reason,before_state,after_state,command_id,command_hash)
      VALUES(@id,@actor,@target,@action,@reason,@before::jsonb,@after::jsonb,@command,@hash)''',
      ),
      parameters: {
        'id': _uuid.v4(),
        'actor': actor,
        'target': target,
        'action': action,
        'reason': reason,
        'before': before == null ? null : jsonEncode(before),
        'after': after == null ? null : jsonEncode(after),
        'command': command,
        'hash': hash,
      },
    );
  }

  Future<Map<String, dynamic>> enroll(Principal actor) async {
    fresh(actor);
    return pool.runTx((tx) async {
      final user = (await tx.execute(
        Sql.named(
          'SELECT email FROM users WHERE id=@id AND google_subject IS NOT NULL FOR UPDATE',
        ),
        parameters: {'id': actor.id},
      ));
      if (user.isEmpty) {
        throw const ApiError(
          403,
          'admin_required',
          'Acesso administrativo não autorizado.',
        );
      }
      final email = user.single.first as String;
      final invitation = await tx.execute(
        Sql.named(
          '''SELECT 1 FROM access_invitations i WHERE i.email=lower(@email) AND i.role='admin' AND i.expires_at>now()
        AND (i.accepted_by IS NULL OR i.accepted_by=@id) AND (i.invited_by IS NULL OR EXISTS(SELECT 1 FROM admin_accounts a WHERE a.user_id=i.invited_by AND a.enabled AND a.activated_at IS NOT NULL)) FOR UPDATE''',
        ),
        parameters: {'email': email, 'id': actor.id},
      );
      if (invitation.isEmpty) {
        throw const ApiError(
          403,
          'invitation_required',
          'Convite de administrador ausente ou expirado.',
        );
      }
      final existing = await tx.execute(
        Sql.named(
          'SELECT activated_at,enabled FROM admin_accounts WHERE user_id=@id FOR UPDATE',
        ),
        parameters: {'id': actor.id},
      );
      if (existing.isNotEmpty &&
          (existing.single[0] != null || existing.single[1] != true)) {
        throw const ApiError(
          409,
          'already_enrolled',
          'Autenticador já configurado ou acesso suspenso.',
        );
      }
      if (existing.isNotEmpty) {
        final pending = await tx.execute(
          Sql.named(
            'SELECT enrollment_expires_at FROM admin_accounts WHERE user_id=@id',
          ),
          parameters: {'id': actor.id},
        );
        if ((pending.single.first as DateTime?)?.isAfter(now()) == true) {
          throw const ApiError(
            409,
            'setup_pending',
            'Configuração já iniciada. Use a chave exibida anteriormente ou aguarde 10 minutos para gerar outra.',
          );
        }
      }
      final secret = AdminCrypto.randomBytes(20);
      final encrypted = await crypto.encryptSecret(actor.id, secret);
      await tx.execute(
        Sql.named(
          '''INSERT INTO admin_accounts(user_id,totp_encrypted,enrollment_expires_at) VALUES(@id,@secret,now()+interval '10 minutes')
        ON CONFLICT(user_id) DO UPDATE SET totp_encrypted=EXCLUDED.totp_encrypted,enrollment_expires_at=EXCLUDED.enrollment_expires_at''',
        ),
        parameters: {'id': actor.id, 'secret': encrypted},
      );
      await tx.execute(
        Sql.named(
          "UPDATE access_invitations SET accepted_by=@id WHERE email=lower(@email) AND role='admin'",
        ),
        parameters: {'id': actor.id, 'email': email},
      );
      final uri = Uri(
        scheme: 'otpauth',
        host: 'totp',
        path: 'ORCEX:$email',
        queryParameters: {
          'secret': AdminCrypto.base32(secret),
          'issuer': 'ORCEX',
          'algorithm': 'SHA1',
          'digits': '6',
          'period': '30',
        },
      );
      return {
        'otpauthUri': uri.toString(),
        'manualKey': AdminCrypto.base32(secret),
        'expiresIn': 600,
      };
    });
  }

  Future<Map<String, dynamic>> unlock(Principal actor, String code) async {
    fresh(actor);
    final response = await pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named(
          'SELECT * FROM admin_accounts WHERE user_id=@id AND enabled FOR UPDATE',
        ),
        parameters: {'id': actor.id},
      );
      if (rows.isEmpty) return <String, dynamic>{'error': 'setup_required'};
      final row = rows.single.toColumnMap();
      final blocked = row['blocked_until'] as DateTime?;
      if (blocked != null && blocked.isAfter(now())) {
        return <String, dynamic>{'error': 'locked'};
      }
      if (row['activated_at'] == null &&
          !(row['enrollment_expires_at'] as DateTime).isAfter(now())) {
        return <String, dynamic>{'error': 'setup_expired'};
      }
      if (row['activated_at'] == null) {
        final validInvite = await tx.execute(
          Sql.named(
            '''SELECT 1 FROM access_invitations i WHERE i.accepted_by=@id AND i.role='admin' AND i.expires_at>now()
          AND (i.invited_by IS NULL OR EXISTS(SELECT 1 FROM admin_accounts a WHERE a.user_id=i.invited_by AND a.enabled AND a.activated_at IS NOT NULL))''',
          ),
          parameters: {'id': actor.id},
        );
        if (validInvite.isEmpty) {
          return <String, dynamic>{'error': 'invitation_expired'};
        }
      }
      final secret = await crypto.decryptSecret(
        actor.id,
        row['totp_encrypted'] as String,
      );
      final counter = AdminCrypto.validCounter(
        secret,
        code,
        now(),
        row['last_counter'] as int,
      );
      if (counter == null) {
        await tx.execute(
          Sql.named(
            "UPDATE admin_accounts SET failed_attempts=CASE WHEN blocked_until<now() THEN 1 ELSE failed_attempts+1 END, blocked_until=CASE WHEN blocked_until<now() THEN NULL WHEN failed_attempts>=4 THEN now()+interval '15 minutes' ELSE blocked_until END WHERE user_id=@id",
          ),
          parameters: {'id': actor.id},
        );
        await _audit(tx, actor.id, 'mfa_rejected');
        return <String, dynamic>{'error': 'invalid_code'};
      }
      await tx.execute(
        Sql.named(
          'UPDATE admin_accounts SET activated_at=COALESCE(activated_at,now()),last_counter=@counter,failed_attempts=0,blocked_until=NULL WHERE user_id=@id',
        ),
        parameters: {'counter': counter, 'id': actor.id},
      );
      await tx.execute(
        Sql.named(
          'DELETE FROM admin_sessions WHERE user_id=@id OR expires_at<now()',
        ),
        parameters: {'id': actor.id},
      );
      final token = AdminCrypto.newSession();
      await tx.execute(
        Sql.named(
          "INSERT INTO admin_sessions(token_hash,user_id,expires_at) VALUES(@hash,@id,now()+interval '5 minutes')",
        ),
        parameters: {'hash': AdminCrypto.digest(token), 'id': actor.id},
      );
      await _audit(
        tx,
        actor.id,
        row['activated_at'] == null ? 'mfa_activated' : 'session_opened',
      );
      return <String, dynamic>{'session': token, 'expiresIn': 300};
    });
    switch (response['error']) {
      case 'invitation_expired':
        throw const ApiError(
          403,
          'invitation_required',
          'Convite de administrador ausente ou expirado.',
        );
      case 'locked':
        throw const ApiError(
          429,
          'admin_locked',
          'Muitas tentativas. Aguarde 15 minutos.',
        );
      case 'setup_required':
        throw const ApiError(
          409,
          'setup_required',
          'Configure seu autenticador primeiro.',
        );
      case 'setup_expired':
        throw const ApiError(
          409,
          'setup_expired',
          'Configuração expirada. Gere uma nova chave.',
        );
      case 'invalid_code':
        throw const ApiError(
          403,
          'invalid_code',
          'Código inválido ou já utilizado. Aguarde o próximo código.',
        );
    }
    return response;
  }

  Future<void> authorize(
    Principal actor,
    String? token, {
    bool recent = false,
    Session? transaction,
  }) async {
    eligible(actor);
    if (token == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const ApiError(
        401,
        'admin_session_required',
        'Desbloqueie a administração com seu autenticador.',
      );
    }
    final db = transaction ?? pool;
    final rows = await db.execute(
      Sql.named(
        '''UPDATE admin_sessions s SET
      request_count=CASE WHEN window_started_at<now()-interval '1 minute' THEN 1 ELSE request_count+1 END,
      window_started_at=CASE WHEN window_started_at<now()-interval '1 minute' THEN now() ELSE window_started_at END
      FROM admin_accounts a WHERE s.token_hash=@hash AND s.user_id=@id AND a.user_id=s.user_id AND a.enabled AND a.activated_at IS NOT NULL
      AND s.expires_at>now() AND (NOT @recent OR s.created_at>now()-interval '2 minutes') RETURNING request_count''',
      ),
      parameters: {
        'hash': AdminCrypto.digest(token),
        'id': actor.id,
        'recent': recent,
      },
    );
    if (rows.isEmpty) {
      throw const ApiError(
        401,
        'admin_session_required',
        'Sessão administrativa expirada. Confirme um novo código.',
      );
    }
    if ((rows.single.first as int) > 60) {
      throw const ApiError(
        429,
        'admin_rate_limit',
        'Muitas solicitações. Aguarde um minuto.',
      );
    }
  }

  Future<Map<String, dynamic>> overview(Principal actor, String? token) async {
    await authorize(actor, token);
    final users = await pool.execute(
      '''SELECT u.id,u.email,u.display_name,u.role,u.seller_approved,EXISTS(SELECT 1 FROM admin_accounts a WHERE a.user_id=u.id AND a.enabled) AS admin_eligible FROM users u WHERE google_subject IS NOT NULL ORDER BY lower(email) LIMIT 100''',
    );
    final invitations = await pool.execute(
      "SELECT email,role,expires_at,accepted_by FROM access_invitations WHERE expires_at>now() ORDER BY created_at DESC LIMIT 100",
    );
    final audit = await pool.execute(
      '''SELECT e.id,e.action,e.reason,e.created_at,u.email AS actor_email,t.email AS target_email,e.after_state FROM admin_audit_events e LEFT JOIN users u ON u.id=e.actor_id LEFT JOIN users t ON t.id=e.target_id ORDER BY e.created_at DESC,e.id DESC LIMIT 50''',
    );
    Map<String, dynamic> jsonRow(ResultRow row) => row.toColumnMap().map(
      (key, value) => MapEntry(
        key,
        value is DateTime ? value.toUtc().toIso8601String() : value,
      ),
    );
    return {
      'users': users.map(jsonRow).toList(),
      'invitations': invitations.map(jsonRow).toList(),
      'audit': audit.map(jsonRow).toList(),
    };
  }

  Future<Map<String, dynamic>> invite(
    Principal actor,
    String? token,
    Map<String, dynamic> data,
  ) async {
    eligible(actor);
    final allowed = {'email', 'role', 'reason', 'commandId'};
    if (data.keys.any((k) => !allowed.contains(k))) {
      throw const ApiError(422, 'invalid_command', 'Campos não permitidos.');
    }
    final email = data['email'],
        role = data['role'],
        reason = data['reason'],
        command = data['commandId'];
    if (email is! String ||
        email.length > 254 ||
        !RegExp(
          r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$',
        ).hasMatch(email) ||
        (role != 'seller' && role != 'admin') ||
        reason is! String ||
        reason.trim().length < 8 ||
        reason.length > 240 ||
        command is! String ||
        !Uuid.isValidUUID(fromString: command)) {
      throw const ApiError(
        422,
        'invalid_command',
        'Informe e-mail válido, perfil e motivo de 8 a 240 caracteres.',
      );
    }
    final normalized = email.toLowerCase();
    final hash = AdminCrypto.digest(
      jsonEncode([normalized, role, reason.trim()]),
    );
    return pool.runTx((tx) async {
      await authorize(actor, token, recent: role == 'admin', transaction: tx);
      final activeAdmin = await tx.execute(
        Sql.named(
          'SELECT user_id FROM admin_accounts WHERE user_id=@id AND enabled AND activated_at IS NOT NULL FOR UPDATE',
        ),
        parameters: {'id': actor.id},
      );
      if (activeAdmin.isEmpty) {
        throw const ApiError(
          403,
          'admin_required',
          'Acesso administrativo suspenso.',
        );
      }
      await tx.execute(
        Sql.named('SELECT pg_advisory_xact_lock(hashtext(@key))'),
        parameters: {'key': 'admin-command:$command'},
      );
      await tx.execute(
        Sql.named('SELECT pg_advisory_xact_lock(hashtext(@key))'),
        parameters: {'key': 'admin-email:$normalized'},
      );
      final prior = await tx.execute(
        Sql.named(
          'SELECT actor_id,command_hash,after_state FROM admin_audit_events WHERE command_id=@id',
        ),
        parameters: {'id': command},
      );
      if (prior.isNotEmpty) {
        if (prior.single[0] != actor.id || prior.single[1] != hash) {
          throw const ApiError(
            409,
            'command_conflict',
            'Identificador já utilizado em outra alteração.',
          );
        }
        return Map<String, dynamic>.from(prior.single[2] as Map);
      }
      final targets = await tx.execute(
        Sql.named(
          'SELECT id,role,seller_approved FROM users WHERE lower(email)=@email AND google_subject IS NOT NULL FOR UPDATE',
        ),
        parameters: {'email': normalized},
      );
      final target = targets.isEmpty ? null : targets.single[0] as String;
      if (target == actor.id) {
        throw const ApiError(
          422,
          'self_change',
          'Não altere o próprio acesso por este painel.',
        );
      }
      if (target != null) {
        final isAdmin = await tx.execute(
          Sql.named(
            'SELECT 1 FROM admin_accounts WHERE user_id=@id AND activated_at IS NOT NULL',
          ),
          parameters: {'id': target},
        );
        if (role == 'admin' && isAdmin.isNotEmpty) {
          throw const ApiError(
            409,
            'already_admin',
            'Esta conta já possui autorização administrativa.',
          );
        }
      }
      final pending = await tx.execute(
        Sql.named(
          "SELECT 1 FROM access_invitations WHERE email=@email AND role=@role AND expires_at>now() AND (accepted_by IS NULL OR @role='admin') FOR UPDATE",
        ),
        parameters: {'email': normalized, 'role': role},
      );
      if (pending.isNotEmpty) {
        throw const ApiError(
          409,
          'invitation_exists',
          'Já existe uma autorização pendente para este e-mail.',
        );
      }
      await tx.execute(
        Sql.named(
          "INSERT INTO access_invitations(email,role,invited_by,reason,expires_at,accepted_by) VALUES(@email,@role,@actor,@reason,now()+interval '7 days',@accepted) ON CONFLICT(email,role) DO UPDATE SET role=EXCLUDED.role,invited_by=EXCLUDED.invited_by,reason=EXCLUDED.reason,expires_at=EXCLUDED.expires_at,accepted_by=EXCLUDED.accepted_by,created_at=now()",
        ),
        parameters: {
          'email': normalized,
          'role': role,
          'actor': actor.id,
          'reason': reason.trim(),
          'accepted': role == 'seller' ? target : null,
        },
      );
      if (role == 'seller' && target != null) {
        await tx.execute(
          Sql.named(
            "UPDATE users SET role='seller',seller_approved=true WHERE id=@id",
          ),
          parameters: {'id': target},
        );
      }
      final result = <String, dynamic>{
        'email': normalized,
        'role': role,
        'status': role == 'seller' && target != null ? 'approved' : 'pending',
      };
      await _audit(
        tx,
        actor.id,
        role == 'admin'
            ? 'admin_invited'
            : target != null
            ? 'seller_approved'
            : 'seller_invited',
        target: target,
        reason: reason.trim(),
        before: targets.isEmpty
            ? null
            : {'role': targets.single[1], 'sellerApproved': targets.single[2]},
        after: result,
        command: command,
        hash: hash,
      );
      return result;
    });
  }

  Future<void> lock(Principal actor, String? token) async {
    await authorize(actor, token);
    await pool.execute(
      Sql.named(
        'DELETE FROM admin_sessions WHERE token_hash=@hash AND user_id=@id',
      ),
      parameters: {'hash': AdminCrypto.digest(token!), 'id': actor.id},
    );
  }
}
