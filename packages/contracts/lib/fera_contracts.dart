enum RequestStatus { received, needsInformation, drafting, quoted, closed }

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.buyerId,
    required this.product,
    required this.description,
    required this.quantity,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String buyerId;
  final String product;
  final String description;
  final int quantity;
  final RequestStatus status;
  final DateTime createdAt;

  factory QuoteRequest.fromJson(Map<String, dynamic> json) => QuoteRequest(
    id: json['id'] as String,
    buyerId: json['buyerId'] as String,
    product: json['product'] as String,
    description: json['description'] as String,
    quantity: json['quantity'] as int,
    status: RequestStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'buyerId': buyerId,
    'product': product,
    'description': description,
    'quantity': quantity,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Material do catálogo. Nome diferente de `Material` para não colidir com o
/// widget do Flutter. O custo unitário trafega como texto decimal (ex.:
/// "13.333333") porque dinheiro não deve passar por `double`.
class CatalogMaterial {
  const CatalogMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitCost,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String unit;
  final String unitCost;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CatalogMaterial.fromJson(Map<String, dynamic> json) =>
      CatalogMaterial(
        id: json['id'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        unitCost: json['unitCost'] as String,
        active: json['active'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'unitCost': unitCost,
    'active': active,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
