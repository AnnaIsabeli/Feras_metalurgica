import 'package:fera_contracts/fera_contracts.dart';
import 'package:fera_mobile/features/materials/material_repository.dart';
import 'package:fera_mobile/features/materials/material_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogMaterial _material(String id, {bool active = true}) => CatalogMaterial(
  id: id,
  name: 'Metalon $id',
  unit: 'metro',
  unitCost: '13.333333',
  active: active,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

class FakeMaterials implements MaterialRepository {
  bool failList = false;
  bool failWrite = false;
  String? lastQuery;
  String? lastStatus;
  final updates = <Map<String, Object?>>[];
  var created = 0;
  @override
  Future<List<CatalogMaterial>> list({
    String? query,
    String status = 'active',
  }) async {
    lastQuery = query;
    lastStatus = status;
    if (failList) throw Exception('Sem conexão');
    return [_material('a')];
  }

  @override
  Future<void> create({
    required String name,
    required String unit,
    required String unitCost,
  }) async {
    if (failWrite) throw Exception('Falha ao salvar');
    created++;
  }

  @override
  Future<void> update(
    String id, {
    String? name,
    String? unit,
    String? unitCost,
    bool? active,
  }) async {
    if (failWrite) throw Exception('Falha ao salvar');
    updates.add({'id': id, 'name': name, 'unitCost': unitCost, 'active': active});
  }
}

void main() {
  test('administrador começa listando todos; vendedor só ativos', () async {
    final repo = FakeMaterials();
    final admin = MaterialViewModel(repo, canManage: true);
    final seller = MaterialViewModel(repo, canManage: false);
    addTearDown(admin.dispose);
    addTearDown(seller.dispose);
    await admin.load();
    expect(repo.lastStatus, 'all');
    await seller.load();
    expect(repo.lastStatus, 'active');
  });

  test('pesquisa e filtro chegam ao repositório', () async {
    final repo = FakeMaterials();
    final model = MaterialViewModel(repo, canManage: true);
    addTearDown(model.dispose);
    await model.load(query: '  metalon ', status: 'inactive');
    expect(repo.lastQuery, 'metalon');
    expect(repo.lastStatus, 'inactive');
  });

  test('falha ao carregar é recuperável', () async {
    final repo = FakeMaterials()..failList = true;
    final model = MaterialViewModel(repo, canManage: true);
    addTearDown(model.dispose);
    await model.load();
    expect(model.error, contains('Sem conexão'));
    repo.failList = false;
    await model.load();
    expect(model.error, isNull);
    expect(model.items, hasLength(1));
  });

  test('salvar cria ou edita conforme o id e informa o erro da API', () async {
    final repo = FakeMaterials();
    final model = MaterialViewModel(repo, canManage: true);
    addTearDown(model.dispose);
    expect(await model.save(name: 'Tinta', unit: 'litro', unitCost: '20'), isTrue);
    expect(repo.created, 1);
    expect(await model.save(id: 'x', name: 'Tinta', unit: 'litro', unitCost: '21'), isTrue);
    expect(repo.updates.single['id'], 'x');
    repo.failWrite = true;
    expect(await model.save(name: 'Tinta', unit: 'litro', unitCost: '20'), isFalse);
    expect(model.error, contains('Falha ao salvar'));
  });

  test('desativar envia só active=false e recarrega a lista', () async {
    final repo = FakeMaterials();
    final model = MaterialViewModel(repo, canManage: true);
    addTearDown(model.dispose);
    await model.setActive(_material('a'), false);
    expect(repo.updates.single, {'id': 'a', 'name': null, 'unitCost': null, 'active': false});
    expect(model.items, isNotEmpty);
  });
}
