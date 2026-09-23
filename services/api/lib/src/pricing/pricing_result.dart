/// Unrounded values in reais; rates are fractions. Round only for display.
class PricingIncomeStatement {
  const PricingIncomeStatement({
    required this.revenue,
    required this.cmv,
    required this.variableExpenses,
    required this.contributionMargin,
    required this.fixedExpenses,
    required this.netProfit,
  });

  final double revenue;
  final double cmv;
  final double variableExpenses;
  final double contributionMargin;
  final double fixedExpenses;
  final double netProfit;

  double get grossMarginRate => 1 - cmv / revenue;
  double get contributionMarginRate => contributionMargin / revenue;
  double get netMarginRate => netProfit / revenue;
}

class PricingResult {
  const PricingResult({
    required this.cmv,
    required this.divisor,
    required this.suggested,
    required this.practiced,
  });

  final double cmv;
  final double divisor;
  final PricingIncomeStatement suggested;
  final PricingIncomeStatement? practiced;

  double get suggestedPrice => suggested.revenue;
  double get markupMultiplier => 1 / divisor;
}
