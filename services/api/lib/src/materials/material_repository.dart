import 'package:fera_contracts/fera_contracts.dart';

enum MaterialStatus { active, inactive, all }

/// Nome + unidade já existem no catálogo (índice único case-insensitive).
class DuplicateMaterialException implements Exception {
  const DuplicateMaterialException();
}

abstract interface class MaterialRepository {
  Future<List<CatalogMaterial>> list({
    String? query,
    MaterialStatus status = MaterialStatus.all,
  });
  Future<CatalogMaterial?> find(String id);
  Future<CatalogMaterial> create({
    required String name,
    required String unit,
    required String unitCost,
  });

  /// Atualiza só os campos informados. Devolve null se o material não existir.
  /// Não há exclusão: desativar (`active: false`) preserva o histórico.
  Future<CatalogMaterial?> update(
    String id, {
    String? name,
    String? unit,
    String? unitCost,
    bool? active,
  });
}
