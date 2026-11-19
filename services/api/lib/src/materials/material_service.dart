import 'package:fera_contracts/fera_contracts.dart';
import '../auth/policy.dart';
import '../auth/principal.dart';
import '../core/api_error.dart';
import '../core/validation.dart';
import 'material_repository.dart';

final _cost = RegExp(r'^\d{1,8}(\.\d{1,6})?$');

ApiError _invalid(String message) =>
    ApiError(422, 'invalid_material', message);

class MaterialService {
  MaterialService(this.repository);
  final MaterialRepository repository;

  /// Admin vê todos (padrão) e pode filtrar; vendedor aprovado só vê ativos,
  /// que são os disponíveis para compor orçamento.
  Future<List<CatalogMaterial>> list(
    Principal actor, {
    String? query,
    String? status,
  }) async {
    authorize(actor, Permission.readMaterials);
    final MaterialStatus filter;
    switch (status) {
      case null:
      case '':
        filter = isAllowed(actor, Permission.readInactiveMaterials)
            ? MaterialStatus.all
            : MaterialStatus.active;
      case 'active':
        filter = MaterialStatus.active;
      case 'inactive':
        authorize(actor, Permission.readInactiveMaterials);
        filter = MaterialStatus.inactive;
      case 'all':
        authorize(actor, Permission.readInactiveMaterials);
        filter = MaterialStatus.all;
      default:
        throw _invalid('Use status active, inactive ou all.');
    }
    final text = query?.trim();
    if (text != null && text.length > 120) {
      throw _invalid('A busca deve ter até 120 caracteres.');
    }
    return repository.list(
      query: text == null || text.isEmpty ? null : text,
      status: filter,
    );
  }

  Future<CatalogMaterial> get(Principal actor, String id) async {
    authorize(actor, Permission.readMaterials);
    final found = isUuid(id) ? await repository.find(id) : null;
    if (found == null ||
        (!found.active && !isAllowed(actor, Permission.readInactiveMaterials))) {
      throw const ApiError(404, 'not_found', 'Material não encontrado.');
    }
    return found;
  }

  Future<CatalogMaterial> create(
    Principal actor,
    Map<String, dynamic> data,
  ) async {
    authorize(actor, Permission.writeMaterials);
    try {
      return await repository.create(
        name: _text(data['name'], 'Nome', 120),
        unit: _text(data['unit'], 'Unidade', 30),
        unitCost: _unitCost(data['unitCost']),
      );
    } on DuplicateMaterialException {
      throw _duplicate;
    }
  }

  Future<CatalogMaterial> update(
    Principal actor,
    String id,
    Map<String, dynamic> data,
  ) async {
    authorize(actor, Permission.writeMaterials);
    final name = data.containsKey('name') ? _text(data['name'], 'Nome', 120) : null;
    final unit = data.containsKey('unit') ? _text(data['unit'], 'Unidade', 30) : null;
    final cost = data.containsKey('unitCost') ? _unitCost(data['unitCost']) : null;
    bool? active;
    if (data.containsKey('active')) {
      final value = data['active'];
      if (value is! bool) throw _invalid('Campo active deve ser verdadeiro ou falso.');
      active = value;
    }
    if (name == null && unit == null && cost == null && active == null) {
      throw _invalid('Informe ao menos um campo: name, unit, unitCost ou active.');
    }
    if (!isUuid(id)) throw _notFound;
    try {
      final updated = await repository.update(
        id,
        name: name,
        unit: unit,
        unitCost: cost,
        active: active,
      );
      if (updated == null) throw _notFound;
      return updated;
    } on DuplicateMaterialException {
      throw _duplicate;
    }
  }

  static const _notFound = ApiError(404, 'not_found', 'Material não encontrado.');
  static const _duplicate = ApiError(
    409,
    'duplicate_material',
    'Já existe um material com este nome e unidade.',
  );

  String _text(Object? value, String label, int max) {
    if (value is! String || value.trim().isEmpty) {
      throw _invalid('$label é obrigatório.');
    }
    if (value.trim().length > max) {
      throw _invalid('$label deve ter até $max caracteres.');
    }
    return value.trim();
  }

  /// Texto decimal com ponto: até 8 dígitos inteiros e 6 decimais (NUMERIC(14,6)).
  /// Aceita número JSON por conveniência, mas valores em notação científica
  /// ou negativos são rejeitados.
  String _unitCost(Object? value) {
    final text = switch (value) {
      String s => s.trim(),
      int i => i.toString(),
      double d => d.toString(),
      _ => '',
    };
    if (!_cost.hasMatch(text)) {
      throw _invalid(
        'Custo unitário deve ser um decimal não negativo com até 6 casas (ex.: 13.333333).',
      );
    }
    return text;
  }
}
