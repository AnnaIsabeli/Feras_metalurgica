import 'package:fera_contracts/fera_contracts.dart';

import '../../core/api_client.dart';

abstract interface class MaterialRepository {
  /// [status]: 'active', 'inactive' ou 'all'. Vendedor só pode 'active'.
  Future<List<CatalogMaterial>> list({String? query, String status = 'active'});
  Future<void> create({
    required String name,
    required String unit,
    required String unitCost,
  });
  Future<void> update(
    String id, {
    String? name,
    String? unit,
    String? unitCost,
    bool? active,
  });
}

class ApiMaterialRepository implements MaterialRepository {
  ApiMaterialRepository(this.api);
  final ApiClient api;

  @override
  Future<List<CatalogMaterial>> list({
    String? query,
    String status = 'active',
  }) async {
    final path = Uri(
      path: '/v1/materials',
      queryParameters: {
        'status': status,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    ).toString();
    final json = await api.get(path);
    return (json['items'] as List)
        .map((item) => CatalogMaterial.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create({
    required String name,
    required String unit,
    required String unitCost,
  }) async {
    await api.post('/v1/materials', {
      'name': name,
      'unit': unit,
      'unitCost': unitCost,
    });
  }

  @override
  Future<void> update(
    String id, {
    String? name,
    String? unit,
    String? unitCost,
    bool? active,
  }) async {
    await api.patch('/v1/materials/$id', {
      'name': ?name,
      'unit': ?unit,
      'unitCost': ?unitCost,
      'active': ?active,
    });
  }
}
