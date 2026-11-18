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
    this.createdBy,
    this.customerName,
    this.customerContact,
  });

  final String id;
  final String? buyerId;
  final String? createdBy;
  final String? customerName;
  final String? customerContact;
  final String product;
  final String description;
  final int quantity;
  final RequestStatus status;
  final DateTime createdAt;

  factory QuoteRequest.fromJson(Map<String, dynamic> json) => QuoteRequest(
    id: json['id'] as String,
    buyerId: json['buyerId'] as String?,
    createdBy: json['createdBy'] as String?,
    customerName: json['customerName'] as String?,
    customerContact: json['customerContact'] as String?,
    product: json['product'] as String,
    description: json['description'] as String,
    quantity: json['quantity'] as int,
    status: RequestStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'buyerId': buyerId,
    'createdBy': createdBy,
    'customerName': customerName,
    'customerContact': customerContact,
    'product': product,
    'description': description,
    'quantity': quantity,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
