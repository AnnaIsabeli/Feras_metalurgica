import 'pricing_input.dart';
import 'pricing_result.dart';

/// Pure calculation matching the source workbook. See docs/PRICING.md.
class PricingCalculator {
  const PricingCalculator();

  PricingResult calculate(PricingInput input) {
    if (input.costs.isEmpty) {
      throw ArgumentError.value(
        input.costs,
        'costs',
        'At least one cost is required',
      );
    }
    var cmv = 0.0;
    for (final cost in input.costs) {
      if (cost.name.trim().isEmpty) {
        throw ArgumentError('Cost name must not be empty');
      }
      _nonNegative(cost.quantity, 'quantity');
      _nonNegative(cost.unitCost, 'unitCost');
      cmv += cost.quantity * cost.unitCost;
    }
    _positive(cmv, 'cmv');

    final rates = {
      'simplesNacionalRate': input.simplesNacionalRate,
      'pisCofinsRate': input.pisCofinsRate,
      'irCsllRate': input.irCsllRate,
      'freightRate': input.freightRate,
      'commissionRate': input.commissionRate,
      'substitutionTaxRate': input.substitutionTaxRate,
      'fixedExpenseRate': input.fixedExpenseRate,
      'targetNetMarginRate': input.targetNetMarginRate,
    };
    for (final entry in rates.entries) {
      _nonNegative(entry.value, entry.key);
      if (entry.value > 1) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Use a fraction between 0 and 1',
        );
      }
    }
    final variableRate =
        input.simplesNacionalRate +
        input.pisCofinsRate +
        input.irCsllRate +
        input.freightRate +
        input.commissionRate +
        input.substitutionTaxRate;
    final divisor =
        1 - (variableRate + input.fixedExpenseRate + input.targetNetMarginRate);
    _positive(divisor, 'divisor');
    final suggestedPrice = cmv / divisor;
    _positive(suggestedPrice, 'suggestedPrice');
    final practicedPrice = input.practicedPrice;
    if (practicedPrice != null) _positive(practicedPrice, 'practicedPrice');

    PricingIncomeStatement statement(double revenue) {
      final variableExpenses = revenue * variableRate;
      final contributionMargin = revenue - cmv - variableExpenses;
      final fixedExpenses = revenue * input.fixedExpenseRate;
      return PricingIncomeStatement(
        revenue: revenue,
        cmv: cmv,
        variableExpenses: variableExpenses,
        contributionMargin: contributionMargin,
        fixedExpenses: fixedExpenses,
        netProfit: contributionMargin - fixedExpenses,
      );
    }

    return PricingResult(
      cmv: cmv,
      divisor: divisor,
      suggested: statement(suggestedPrice),
      practiced: practicedPrice == null ? null : statement(practicedPrice),
    );
  }

  static void _nonNegative(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, 'Must be finite and non-negative');
    }
  }

  static void _positive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'Must be finite and greater than zero',
      );
    }
  }
}
