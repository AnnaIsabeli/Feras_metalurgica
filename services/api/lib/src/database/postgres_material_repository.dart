import 'package:fera_contracts/fera_contracts.dart';
import 'package:postgres/postgres.dart';
import '../materials/material_repository.dart';

/// Materiais no PostgreSQL. Todas as consultas são parametrizadas; os únicos
/// trechos de SQL montados dinamicamente são constantes escritas aqui.
///
/// O custo é lido como texto (`unit_cost::text`) e gravado via `::text::numeric`
/// para nunca passar por `double`.
class PostgresMaterialRepository implements MaterialRepository {
  PostgresMaterialRepository(this.pool);
  final Pool pool;

  static const _columns =
      'id, name, unit, unit_cost::text AS unit_cost, active, created_at, updated_at';

  @override
  Future<List<CatalogMaterial>> list({
    String? query,
    MaterialStatus status = MaterialStatus.all,
  }) async {
    final where = <String>[];
    final parameters = <String, Object?>{};
    if (query != null) {
      where.add('(name ILIKE @q OR unit ILIKE @q)');
      parameters['q'] = '%${_escapeLike(query)}%';
    }
    if (status == MaterialStatus.active) where.add('active = true');
    if (status == MaterialStatus.inactive) where.add('active = false');
    final result = await pool.execute(
      Sql.named(
        'SELECT $_columns FROM materials '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY lower(name), lower(unit), id LIMIT 500',
      ),
      parameters: parameters,
    );
    return result.map((row) => _map(row.toColumnMap())).toList();
  }

  @override
  Future<CatalogMaterial?> find(String id) async {
    final result = await pool.execute(
      Sql.named('SELECT $_columns FROM materials WHERE id = @id'),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _map(result.first.toColumnMap());
  }

  @override
  Future<CatalogMaterial> create({
    required String name,
    required String unit,
    required String unitCost,
  }) async {
    try {
      final result = await pool.execute(
        Sql.named(
          'INSERT INTO materials (name, unit, unit_cost) '
          'VALUES (@name, @unit, @cost::text::numeric) RETURNING $_columns',
        ),
        parameters: {'name': name, 'unit': unit, 'cost': unitCost},
      );
      return _map(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == '23505') throw const DuplicateMaterialException();
      rethrow;
    }
  }

  @override
  Future<CatalogMaterial?> update(
    String id, {
    String? name,
    String? unit,
    String? unitCost,
    bool? active,
  }) async {
    final sets = <String>['updated_at = now()'];
    final parameters = <String, Object?>{'id': id};
    if (name != null) {
      sets.add('name = @name');
      parameters['name'] = name;
    }
    if (unit != null) {
      sets.add('unit = @unit');
      parameters['unit'] = unit;
    }
    if (unitCost != null) {
      sets.add('unit_cost = @cost::text::numeric');
      parameters['cost'] = unitCost;
    }
    if (active != null) {
      sets.add('active = @active');
      parameters['active'] = active;
    }
    try {
      final result = await pool.execute(
        Sql.named(
          'UPDATE materials SET ${sets.join(', ')} '
          'WHERE id = @id RETURNING $_columns',
        ),
        parameters: parameters,
      );
      return result.isEmpty ? null : _map(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == '23505') throw const DuplicateMaterialException();
      rethrow;
    }
  }

  /// Impede que `%` e `_` digitados na busca funcionem como curingas.
  String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  CatalogMaterial _map(Map<String, dynamic> row) => CatalogMaterial(
    id: row['id'] as String,
    name: row['name'] as String,
    unit: row['unit'] as String,
    unitCost: row['unit_cost'] as String,
    active: row['active'] as bool,
    createdAt: row['created_at'] as DateTime,
    updatedAt: row['updated_at'] as DateTime,
  );
}
