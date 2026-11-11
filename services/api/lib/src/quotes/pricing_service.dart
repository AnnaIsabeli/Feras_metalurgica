import 'dart:convert';
import '../auth/principal.dart';
import '../core/api_error.dart';
import '../http/pricing_endpoint.dart';
import 'pricing_repository.dart';

class PricingService {
  PricingService(this.repository);
  final PricingRepository repository;
  static final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void authorize(Principal actor) {
    if (actor.role != UserRole.seller || !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_required',
        'Somente vendedores aprovados podem acessar precificações.',
      );
    }
  }

  void requestId(String id) {
    if (!uuid.hasMatch(id)) {
      throw const ApiError(422, 'invalid_request_id', 'Solicitação inválida.');
    }
  }

  Future<List<Map<String, dynamic>>> materials(Principal actor) {
    authorize(actor);
    return repository.materials();
  }

  Future<Map<String, dynamic>> latest(Principal actor, String id) async {
    authorize(actor);
    requestId(id);
    final saved = await repository.latest(id);
    if (saved == null) {
      throw const ApiError(
        404,
        'pricing_not_found',
        'Nenhuma precificação encontrada para esta solicitação.',
      );
    }
    return saved;
  }

  Future<Map<String, dynamic>> save(
    Principal actor,
    String id,
    Map<String, dynamic> data,
  ) async {
    authorize(actor);
    requestId(id);
    // Copy input to ensure normalization never mutates the caller's object.
    final input = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    final costs = input['costs'];
    if (costs is! List || costs.isEmpty || costs.length > 100) {
      throw const ApiError(
        422,
        'invalid_pricing',
        'Informe de 1 a 100 insumos.',
      );
    }
    for (final cost in costs) {
      if (cost is! Map<String, dynamic>) {
        throw const ApiError(422, 'invalid_pricing', 'Insumo inválido.');
      }
      final materialId = cost['materialId'];
      if (materialId != null) {
        if (materialId is! String || !uuid.hasMatch(materialId)) {
          throw const ApiError(422, 'invalid_material', 'Material inválido.');
        }
        final material = await repository.material(materialId);
        if (material == null) {
          throw const ApiError(
            422,
            'invalid_material',
            'Material inexistente ou inativo.',
          );
        }
        // Catalog-backed items use the current catalog cost, never client prices.
        cost['name'] = material['name'];
        cost['unit'] = material['unit'];
        cost['unitCost'] = material['unitCost'];
      }
      final name = cost['name'];
      final unit = cost['unit'];
      final quantity = cost['quantity'];
      final unitCost = cost['unitCost'];
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 120 ||
          unit is! String ||
          unit.trim().isEmpty ||
          unit.length > 30 ||
          !_decimal(quantity, 3, 999999999.999, positive: true) ||
          !_decimal(unitCost, 6, 99999999.999999)) {
        throw const ApiError(
          422,
          'invalid_pricing',
          'Informe nome, unidade, quantidade positiva (até 3 casas) e custo não negativo (até 6 casas).',
        );
      }
      cost['name'] = name.trim();
      cost['unit'] = unit.trim();
      if ((quantity as num) * (unitCost as num) * 100 > 9007199254740991) {
        throw const ApiError(
          422,
          'invalid_pricing',
          'Valor do item muito alto.',
        );
      }
    }
    final result = calculatePricing(input);
    final statement = (result['practiced'] ?? result['suggested']) as Map;
    final cents = (statement['revenue'] as num) * 100;
    if (cents < 0 || cents > 9007199254740991) {
      throw const ApiError(
        422,
        'invalid_pricing',
        'Preço total fora do limite.',
      );
    }
    final saved = await repository.save(
      requestId: id,
      actorId: actor.id,
      input: input,
      result: result,
      totalPriceCents: cents.round(),
    );
    if (saved == null) {
      throw const ApiError(
        404,
        'request_not_found',
        'Solicitação não encontrada.',
      );
    }
    return saved;
  }

  bool _decimal(
    Object? value,
    int places,
    double maximum, {
    bool positive = false,
  }) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value > maximum ||
        (positive && value == 0)) {
      return false;
    }
    final factor = places == 3 ? 1000 : 1000000;
    final scaled = value * factor;
    return (scaled - scaled.round()).abs() <= 0.000001;
  }
}
