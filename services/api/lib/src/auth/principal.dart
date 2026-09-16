enum UserRole { buyer, seller }

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

class DenyAllIdentityVerifier implements IdentityVerifier {
  @override
  Future<Principal?> verify(String bearerToken) async => null;
}

/// Local demonstration only. Never selected outside explicit development mode.
class DevelopmentIdentityVerifier implements IdentityVerifier {
  static const buyerId = '00000000-0000-4000-8000-000000000001';
  static const sellerId = '00000000-0000-4000-8000-000000000002';
  @override
  Future<Principal?> verify(String bearerToken) async => switch (bearerToken) {
    'demo-buyer' => const Principal(buyerId, UserRole.buyer),
    'demo-seller' => const Principal(
      sellerId,
      UserRole.seller,
      sellerApproved: true,
    ),
    _ => null,
  };
}
