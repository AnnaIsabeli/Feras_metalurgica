import 'dart:io';
import 'package:fera_api/src/admin/admin_crypto.dart';
import 'package:fera_api/src/admin/admin_service.dart';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/core/api_error.dart';
import 'package:fera_api/src/database/postgres_google_account_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  final url = Platform.environment['TEST_DATABASE_URL'];
  group('administrator security', () {
    late Pool pool;
    late AdminCrypto crypto;
    late AdminService service;
    late Principal owner;
    late String buyerId;
    late String buyerEmail;
    final ids = <String>[];
    final secret = List<int>.generate(20, (i) => i + 1);
    final emails = <String>[];
    setUp(() async {
      pool = Pool.withUrl(url!);
      crypto = AdminCrypto(List.filled(32, 7));
      service = AdminService(pool, crypto);
      ids.clear();
      emails.clear();
      final ownerId = const Uuid().v4();
      buyerId = const Uuid().v4();
      ids.addAll([ownerId, buyerId]);
      buyerEmail = 'buyer-$buyerId@example.invalid';
      emails.addAll(['admin-$ownerId@example.invalid', buyerEmail]);
      for (var i = 0; i < ids.length; i++) {
        await pool.execute(
          Sql.named(
            "INSERT INTO users(id,email,display_name,role,seller_approved,google_subject) VALUES(@id,@email,'Security test','buyer',false,@subject)",
          ),
          parameters: {
            'id': ids[i],
            'email': emails[i],
            'subject': 'test-${ids[i]}',
          },
        );
      }
      await pool.execute(
        Sql.named(
          'INSERT INTO admin_accounts(user_id,totp_encrypted,activated_at) VALUES(@id,@secret,now())',
        ),
        parameters: {
          'id': ownerId,
          'secret': await crypto.encryptSecret(ownerId, secret),
        },
      );
      owner = Principal(
        ownerId,
        UserRole.buyer,
        adminEligible: true,
        googleVerified: true,
        tokenIssuedAt: DateTime.now().toUtc(),
      );
    });
    tearDown(() async {
      for (final id in ids) {
        await pool.execute(
          Sql.named(
            'DELETE FROM access_invitations WHERE invited_by=@id OR accepted_by=@id',
          ),
          parameters: {'id': id},
        );
        await pool.execute(
          Sql.named(
            'DELETE FROM admin_audit_events WHERE actor_id=@id OR target_id=@id',
          ),
          parameters: {'id': id},
        );
      }
      for (final id in ids.reversed) {
        await pool.execute(
          Sql.named('DELETE FROM admin_accounts WHERE user_id=@id'),
          parameters: {'id': id},
        );
        await pool.execute(
          Sql.named('DELETE FROM users WHERE id=@id'),
          parameters: {'id': id},
        );
      }
      await pool.close();
    });
    late String lastCode;
    Future<String> unlock() async {
      lastCode = AdminCrypto.totp(
        secret,
        DateTime.now().millisecondsSinceEpoch ~/ 30000,
      );
      return (await service.unlock(owner, lastCode))['session'] as String;
    }

    Map<String, dynamic> invitation(
      String role, {
      String? email,
      String? command,
    }) => {
      'email': email ?? buyerEmail,
      'role': role,
      'reason': 'Autorização da equipe ORCEX',
      'commandId': command ?? const Uuid().v4(),
    };
    Matcher error(String code) =>
        isA<ApiError>().having((e) => e.code, 'code', code);

    test(
      'ordinary users, forged eligibility and missing MFA cannot administer',
      () async {
        final buyer = Principal(
          buyerId,
          UserRole.buyer,
          googleVerified: true,
          tokenIssuedAt: DateTime.now(),
        );
        await expectLater(
          service.overview(buyer, null),
          throwsA(error('admin_required')),
        );
        await expectLater(
          service.enroll(buyer),
          throwsA(error('admin_required')),
        );
        await expectLater(
          service.overview(owner, null),
          throwsA(error('admin_session_required')),
        );
        await expectLater(
          service.unlock(
            Principal(
              owner.id,
              UserRole.buyer,
              adminEligible: true,
              googleVerified: true,
              tokenIssuedAt: DateTime.now().subtract(
                const Duration(minutes: 6),
              ),
            ),
            '000000',
          ),
          throwsA(error('admin_login_required')),
        );
      },
    );
    test(
      'MFA codes are one-time, sessions hashed, expiring, user bound and revocable',
      () async {
        final token = await unlock();
        final stored = (await pool.execute(
          Sql.named('SELECT token_hash FROM admin_sessions WHERE user_id=@id'),
          parameters: {'id': owner.id},
        )).single.first;
        expect(stored, AdminCrypto.digest(token));
        expect(stored, isNot(token));
        expect((await service.overview(owner, token))['users'], isA<List>());
        await expectLater(
          service.unlock(owner, lastCode),
          throwsA(error('invalid_code')),
        );
        final other = Principal(
          buyerId,
          UserRole.buyer,
          adminEligible: true,
          googleVerified: true,
          tokenIssuedAt: DateTime.now(),
        );
        await expectLater(
          service.overview(other, token),
          throwsA(error('admin_session_required')),
        );
        await pool.execute(
          Sql.named(
            "UPDATE admin_sessions SET expires_at=now()-interval '1 second' WHERE user_id=@id",
          ),
          parameters: {'id': owner.id},
        );
        await expectLater(
          service.overview(owner, token),
          throwsA(error('admin_session_required')),
        );
        await pool.execute(
          Sql.named(
            "UPDATE admin_sessions SET expires_at=now()+interval '1 minute' WHERE user_id=@id",
          ),
          parameters: {'id': owner.id},
        );
        await pool.execute(
          Sql.named(
            'UPDATE admin_accounts SET enabled=false WHERE user_id=@id',
          ),
          parameters: {'id': owner.id},
        );
        await expectLater(
          service.invite(owner, token, invitation('seller')),
          throwsA(anything),
        );
      },
    );
    test(
      'five invalid codes lock the administrator instead of allowing brute force',
      () async {
        final current = AdminCrypto.totp(
          secret,
          DateTime.now().millisecondsSinceEpoch ~/ 30000,
        );
        final invalid = current == '000000' ? '111111' : '000000';
        for (var i = 0; i < 5; i++) {
          await expectLater(
            service.unlock(owner, invalid),
            throwsA(error('invalid_code')),
          );
        }
        await expectLater(
          service.unlock(owner, current),
          throwsA(error('admin_locked')),
        );
      },
    );
    test(
      'seller approval is explicit, audited, idempotent and does not create admins',
      () async {
        final token = await unlock();
        final data = invitation('seller');
        final results = await Future.wait([
          service.invite(owner, token, data),
          service.invite(owner, token, data),
        ]);
        expect(results[0], results[1]);
        expect(results[0]['status'], 'approved');
        final buyer = await PostgresGoogleAccountRepository(
          pool,
        ).resolve(subject: 'test-$buyerId', email: buyerEmail, name: 'Test');
        expect(buyer!.role, UserRole.seller);
        expect(buyer.sellerApproved, isTrue);
        expect(buyer.adminEligible, isFalse);
        final count = (await pool.execute(
          Sql.named(
            'SELECT count(*) FROM admin_audit_events WHERE command_id=@id',
          ),
          parameters: {'id': data['commandId']},
        )).single.first;
        expect(count, 1);
        await expectLater(
          service.invite(owner, token, {...data, 'role': 'admin'}),
          throwsA(error('command_conflict')),
        );
        await expectLater(
          service.invite(owner, token, {
            ...invitation('seller'),
            'isAdmin': true,
          }),
          throwsA(error('invalid_command')),
        );
      },
    );
    test(
      'invited administrator must enroll their own MFA before getting a session',
      () async {
        final token = await unlock();
        await service.invite(owner, token, invitation('admin'));
        final resolved = (await PostgresGoogleAccountRepository(
          pool,
        ).resolve(subject: 'test-$buyerId', email: buyerEmail, name: 'Test'))!;
        expect(resolved.role, UserRole.buyer);
        expect(resolved.adminEligible, isTrue);
        final target = Principal(
          buyerId,
          resolved.role,
          adminEligible: resolved.adminEligible,
          googleVerified: true,
          tokenIssuedAt: DateTime.now(),
        );
        await expectLater(
          service.overview(target, token),
          throwsA(error('admin_session_required')),
        );
        final setup = await service.enroll(target);
        expect(Uri.parse(setup['otpauthUri'] as String).scheme, 'otpauth');
        await expectLater(
          service.enroll(target),
          throwsA(error('setup_pending')),
        );
        final row =
            (await pool.execute(
                  Sql.named(
                    'SELECT totp_encrypted FROM admin_accounts WHERE user_id=@id',
                  ),
                  parameters: {'id': buyerId},
                )).single.first
                as String;
        final ownSecret = await crypto.decryptSecret(buyerId, row);
        final ownToken =
            (await service.unlock(
                  target,
                  AdminCrypto.totp(
                    ownSecret,
                    DateTime.now().millisecondsSinceEpoch ~/ 30000,
                  ),
                ))['session']
                as String;
        expect(
          (await service.overview(target, ownToken))['users'],
          isA<List>(),
        );
        await expectLater(
          service.enroll(target),
          throwsA(error('already_enrolled')),
        );
      },
    );
    test(
      'seller and administrator invitations can coexist without bypassing MFA',
      () async {
        final token = await unlock();
        await service.invite(owner, token, invitation('admin'));
        await service.invite(owner, token, invitation('seller'));
        final resolved = (await PostgresGoogleAccountRepository(
          pool,
        ).resolve(subject: 'test-$buyerId', email: buyerEmail, name: 'Test'))!;
        expect(resolved.role, UserRole.seller);
        expect(resolved.adminEligible, isTrue);
        final target = Principal(
          buyerId,
          resolved.role,
          sellerApproved: true,
          adminEligible: true,
          googleVerified: true,
          tokenIssuedAt: DateTime.now(),
        );
        expect((await service.enroll(target))['otpauthUri'], isA<String>());
        await expectLater(
          service.overview(target, null),
          throwsA(error('admin_session_required')),
        );
      },
    );
    test(
      'future seller invitations apply only to the verified invited email',
      () async {
        final token = await unlock();
        final email = 'future-${const Uuid().v4()}@example.invalid';
        emails.add(email);
        await service.invite(owner, token, invitation('seller', email: email));
        final accounts = PostgresGoogleAccountRepository(pool);
        final newUser = (await accounts.resolve(
          subject: 'subject-$email',
          email: email,
          name: 'Future seller',
        ))!;
        ids.add(newUser.id);
        expect(newUser.role, UserRole.seller);
        expect(newUser.sellerApproved, isTrue);
        expect(newUser.adminEligible, isFalse);
        final outsiderEmail = 'outsider-${const Uuid().v4()}@example.invalid';
        final outsider = (await accounts.resolve(
          subject: 'subject-$outsiderEmail',
          email: outsiderEmail,
          name: 'Ordinary buyer',
        ))!;
        ids.add(outsider.id);
        expect(outsider.role, UserRole.buyer);
        expect(outsider.sellerApproved, isFalse);
        expect(outsider.adminEligible, isFalse);
      },
    );
  }, skip: url == null ? 'Set TEST_DATABASE_URL.' : false);
}
