/// Perfis do sistema. `buyer` é o perfil "Cliente" na interface; o identificador
/// técnico foi mantido para não exigir migração de dados (ver docs/DECISIONS.md).
enum UserRole { buyer, seller, admin }

class Principal {
  const Principal(this.id, this.role, {this.sellerApproved = false});
  final String id;
  final UserRole role;
  final bool sellerApproved;
}

/// Boundary for verified identity. Google implementation is intentionally pending.
abstract interface class IdentityVerifier {
  Future<Principal?> verify(String bearerToken);
}

/// Autenticação final ainda não integrada: nega todo acesso privado, inclusive
/// os tokens `demo-*`. É o verificador usado fora de development.
class DenyAllIdentityVerifier implements IdentityVerifier {
  @override
  Future<Principal?> verify(String bearerToken) async => null;
}

/// Local demonstration only. Never selected outside explicit development mode.
/// Os IDs correspondem aos usuários de database/seeds/development.sql.
class DevelopmentIdentityVerifier implements IdentityVerifier {
  static const buyerId = '00000000-0000-4000-8000-000000000001';
  static const sellerId = '00000000-0000-4000-8000-000000000002';
  static const adminId = '00000000-0000-4000-8000-000000000003';
  static const pendingSellerId = '00000000-0000-4000-8000-000000000004';
  static const otherBuyerId = '00000000-0000-4000-8000-000000000005';

  @override
  Future<Principal?> verify(String bearerToken) async => switch (bearerToken) {
    'demo-buyer' => const Principal(buyerId, UserRole.buyer),
    'demo-buyer-2' => const Principal(otherBuyerId, UserRole.buyer),
    'demo-seller' => const Principal(
      sellerId,
      UserRole.seller,
      sellerApproved: true,
    ),
    'demo-seller-pending' => const Principal(pendingSellerId, UserRole.seller),
    'demo-admin' => const Principal(adminId, UserRole.admin),
    _ => null,
  };
}
