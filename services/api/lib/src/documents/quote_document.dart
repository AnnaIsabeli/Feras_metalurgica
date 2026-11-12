/// Customer-facing data only. Never pass financial calculation objects to the PDF.
class QuoteDocumentItem {
  const QuoteDocumentItem({
    required this.name,
    required this.unit,
    required this.quantity,
  });
  final String name;
  final String unit;
  final num quantity;
}

class QuoteDocument {
  const QuoteDocument({
    required this.requestId,
    required this.pricingId,
    required this.savedAt,
    required this.customerName,
    required this.customerEmail,
    required this.product,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.items,
    this.deliveryLeadTime,
  });
  final String requestId;
  final String pricingId;
  final DateTime savedAt;
  final String customerName;
  final String customerEmail;
  final String product;
  final String description;
  final int quantity;
  final int unitPriceCents;
  int get totalPriceCents => unitPriceCents * quantity;
  final List<QuoteDocumentItem> items;
  final String? deliveryLeadTime;
}

abstract interface class QuoteDocumentRepository {
  Future<QuoteDocument?> find(String requestId, {String? pricingId});
}
