/// Sessão resolvida pela API em `/v1/me`. O papel e as permissões vêm do
/// servidor, nunca do aplicativo. A interface só usa isto para mostrar ou
/// esconder opções; quem nega a operação de fato é a API.
class Session {
  const Session({
    required this.id,
    required this.role,
    required this.sellerApproved,
    required this.permissions,
  });

  final String id;
  final String role;
  final bool sellerApproved;
  final Set<String> permissions;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    role: json['role'] as String,
    sellerApproved: json['sellerApproved'] as bool,
    permissions: {...(json['permissions'] as List).cast<String>()},
  );

  bool can(String permission) => permissions.contains(permission);

  bool get isPendingSeller => role == 'seller' && !sellerApproved;

  String get roleLabel => switch (role) {
    'buyer' => 'Cliente',
    'seller' => sellerApproved ? 'Vendedor' : 'Vendedor (aguardando aprovação)',
    'admin' => 'Administrador',
    _ => role,
  };
}
