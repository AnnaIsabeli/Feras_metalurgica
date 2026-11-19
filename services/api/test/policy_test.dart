import 'package:fera_api/src/auth/policy.dart';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/core/api_error.dart';
import 'package:test/test.dart';

/// Matriz de permissões (docs/PERMISSIONS.md) escrita como dados.
/// Se a política mudar, este teste obriga a atualizar a matriz e a documentação.
void main() {
  const buyer = Principal('buyer-a', UserRole.buyer);
  const seller = Principal('seller', UserRole.seller, sellerApproved: true);
  const pendingSeller = Principal('pending', UserRole.seller);
  const admin = Principal('admin', UserRole.admin);

  final matrix = <String, Map<Permission, bool>>{
    'cliente': {
      Permission.createQuote: true,
      Permission.listQuotes: true,
      Permission.readQuote: true,
      Permission.downloadQuotePdf: true,
      Permission.readMaterials: false,
      Permission.readInactiveMaterials: false,
      Permission.writeMaterials: false,
    },
    'vendedor aprovado': {
      Permission.createQuote: true,
      Permission.listQuotes: true,
      Permission.readQuote: true,
      Permission.downloadQuotePdf: true,
      Permission.readMaterials: true,
      Permission.readInactiveMaterials: false,
      Permission.writeMaterials: false,
    },
    'vendedor não aprovado': {
      for (final p in Permission.values) p: false,
    },
    'administrador': {
      Permission.createQuote: false,
      Permission.listQuotes: true,
      Permission.readQuote: true,
      Permission.downloadQuotePdf: true,
      Permission.readMaterials: true,
      Permission.readInactiveMaterials: true,
      Permission.writeMaterials: true,
    },
  };
  final principals = {
    'cliente': buyer,
    'vendedor aprovado': seller,
    'vendedor não aprovado': pendingSeller,
    'administrador': admin,
  };

  test('a matriz cobre todas as permissões de todos os perfis', () {
    for (final row in matrix.values) {
      expect(row.keys.toSet(), Permission.values.toSet());
    }
  });

  for (final profile in matrix.keys) {
    for (final entry in matrix[profile]!.entries) {
      test('$profile / ${entry.key.name}: ${entry.value ? 'permite' : 'nega'}', () {
        final principal = principals[profile]!;
        expect(isAllowed(principal, entry.key), entry.value);
        if (entry.value) {
          authorize(principal, entry.key);
        } else {
          expect(
            () => authorize(principal, entry.key),
            throwsA(
              isA<ApiError>().having((e) => e.status, 'status', 403),
            ),
          );
        }
      });
    }
  }

  test('vendedor não aprovado recebe o código seller_not_approved', () {
    expect(
      () => authorize(pendingSeller, Permission.listQuotes),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'seller_not_approved'),
      ),
    );
  });

  test('cliente só acessa o que é seu; recurso alheio responde 404', () {
    authorize(buyer, Permission.readQuote, ownerId: 'buyer-a');
    for (final permission in [
      Permission.readQuote,
      Permission.downloadQuotePdf,
    ]) {
      expect(
        () => authorize(buyer, permission, ownerId: 'buyer-b'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 404)),
      );
    }
    authorize(seller, Permission.readQuote, ownerId: 'buyer-b');
    authorize(admin, Permission.downloadQuotePdf, ownerId: 'buyer-b');
  });

  test('permissionsFor lista só o que o perfil pode', () {
    expect(permissionsFor(buyer), contains('createQuote'));
    expect(permissionsFor(buyer), isNot(contains('writeMaterials')));
    expect(permissionsFor(admin), contains('writeMaterials'));
    expect(permissionsFor(pendingSeller), isEmpty);
  });
}
