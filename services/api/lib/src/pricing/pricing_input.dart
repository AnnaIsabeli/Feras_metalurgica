/// A resolved material cost. Quantities and unit costs use the same unit.
/// Keep fractional unit costs (e.g. R$22 / 6 metres) without rounding.
class PricingCost {
  const PricingCost({
    required this.name,
    required this.quantity,
    required this.unitCost,
  });

  final String name;
  final double quantity;
  final double unitCost;
}

/// All rates are fractions: 4.5% = 0.045. No implicit fiscal defaults.
class PricingInput {
  PricingInput({
    required List<PricingCost> costs,
    required this.simplesNacionalRate,
    required this.pisCofinsRate,
    required this.irCsllRate,
    required this.freightRate,
    required this.commissionRate,
    required this.substitutionTaxRate,
    required this.fixedExpenseRate,
    required this.targetNetMarginRate,
    this.practicedPrice,
  }) : costs = List.unmodifiable(costs);

  final List<PricingCost> costs;
  final double simplesNacionalRate;
  final double pisCofinsRate;
  final double irCsllRate;
  final double freightRate;
  final double commissionRate;
  final double substitutionTaxRate;
  final double fixedExpenseRate;
  final double targetNetMarginRate;

  /// Optional negotiated price, in reais, for a second income statement.
  final double? practicedPrice;
}
