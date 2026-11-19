import 'package:fera_api/src/materials/material_repository.dart';
import 'package:fera_api/src/quotes/quote_repository.dart';
import 'package:fera_contracts/fera_contracts.dart';
import 'package:uuid/uuid.dart';

class MemoryQuotes implements QuoteRepository {
  final items = <QuoteRequest>[];
  @override
  Future<QuoteRequest> create(QuoteRequest request) async {
    items.add(request);
    return request;
  }

  @override
  Future<QuoteRequest?> find(String id) async {
    for (final q in items) {
      if (q.id == id) return q;
    }
    return null;
  }

  @override
  Future<List<QuoteRequest>> list({String? buyerId}) async =>
      items.where((q) => buyerId == null || q.buyerId == buyerId).toList();
}

class MemoryMaterials implements MaterialRepository {
  final items = <CatalogMaterial>[];

  String _key(String name, String unit) =>
      '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';

  bool _duplicate(String name, String unit, {String? ignoreId}) => items.any(
    (m) => m.id != ignoreId && _key(m.name, m.unit) == _key(name, unit),
  );

  @override
  Future<List<CatalogMaterial>> list({
    String? query,
    MaterialStatus status = MaterialStatus.all,
  }) async => items.where((m) {
    if (status == MaterialStatus.active && !m.active) return false;
    if (status == MaterialStatus.inactive && m.active) return false;
    if (query == null) return true;
    final q = query.toLowerCase();
    return m.name.toLowerCase().contains(q) || m.unit.toLowerCase().contains(q);
  }).toList();

  @override
  Future<CatalogMaterial?> find(String id) async {
    for (final m in items) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Future<CatalogMaterial> create({
    required String name,
    required String unit,
    required String unitCost,
  }) async {
    if (_duplicate(name, unit)) throw const DuplicateMaterialException();
    final now = DateTime.now().toUtc();
    final material = CatalogMaterial(
      id: const Uuid().v4(),
      name: name,
      unit: unit,
      unitCost: unitCost,
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    items.add(material);
    return material;
  }

  @override
  Future<CatalogMaterial?> update(
    String id, {
    String? name,
    String? unit,
    String? unitCost,
    bool? active,
  }) async {
    final index = items.indexWhere((m) => m.id == id);
    if (index < 0) return null;
    final old = items[index];
    final newName = name ?? old.name;
    final newUnit = unit ?? old.unit;
    if (_duplicate(newName, newUnit, ignoreId: id)) {
      throw const DuplicateMaterialException();
    }
    final updated = CatalogMaterial(
      id: old.id,
      name: newName,
      unit: newUnit,
      unitCost: unitCost ?? old.unitCost,
      active: active ?? old.active,
      createdAt: old.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    items[index] = updated;
    return updated;
  }
}
