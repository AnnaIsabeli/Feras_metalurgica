import '../core/api_error.dart';
import 'principal.dart';

/// Operações protegidas. A matriz de permissões (docs/PERMISSIONS.md) existe
/// em um único lugar: a função [isAllowed]. Handlers e serviços só chamam
/// [authorize]; nada de `if (role == ...)` espalhado.
enum Permission {
  createQuote,
  listQuotes,
  readQuote,
  downloadQuotePdf,
  readMaterials,
  readInactiveMaterials,
  writeMaterials,
}

bool _isApprovedSeller(Principal p) =>
    p.role == UserRole.seller && p.sellerApproved;

/// Decisão no nível do perfil (sem olhar o dono do recurso).
/// Qualquer permissão não listada é negada por padrão.
bool isAllowed(Principal actor, Permission permission) {
  switch (permission) {
    case Permission.createQuote:
      return actor.role == UserRole.buyer || _isApprovedSeller(actor);
    case Permission.listQuotes:
    case Permission.readQuote:
    case Permission.downloadQuotePdf:
      return actor.role == UserRole.buyer ||
          actor.role == UserRole.admin ||
          _isApprovedSeller(actor);
    case Permission.readMaterials:
      return actor.role == UserRole.admin || _isApprovedSeller(actor);
    case Permission.readInactiveMaterials:
    case Permission.writeMaterials:
      return actor.role == UserRole.admin;
  }
}

/// Lança [ApiError] se [actor] não puder executar [permission].
///
/// Para recursos com dono (`readQuote`, `downloadQuotePdf`), passe [ownerId]:
/// o Cliente só acessa o que é seu. Recurso de outro cliente responde 404
/// (igual a "não existe"), para não revelar que o registro existe.
void authorize(Principal actor, Permission permission, {String? ownerId}) {
  if (!isAllowed(actor, permission)) {
    if (actor.role == UserRole.seller && !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_not_approved',
        'Acesso de vendedor não aprovado.',
      );
    }
    throw const ApiError(
      403,
      'forbidden',
      'Seu perfil não tem permissão para esta operação.',
    );
  }
  final ownedOperation =
      permission == Permission.readQuote ||
      permission == Permission.downloadQuotePdf;
  if (ownedOperation &&
      actor.role == UserRole.buyer &&
      ownerId != null &&
      ownerId != actor.id) {
    throw const ApiError(404, 'not_found', 'Solicitação não encontrada.');
  }
}

/// Permissões do perfil, para a interface decidir o que mostrar (/v1/me).
/// A interface só representa: quem nega de fato é [authorize] na API.
List<String> permissionsFor(Principal actor) => [
  for (final p in Permission.values)
    if (isAllowed(actor, p)) p.name,
];
