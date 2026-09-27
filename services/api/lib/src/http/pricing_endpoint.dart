import '../core/api_error.dart';
import '../pricing/pricing_calculator.dart';
import '../pricing/pricing_input.dart';
import '../pricing/pricing_result.dart';

Map<String, dynamic> calculatePricing(Map<String, dynamic> data) {
  double number(Object? value) {
    if (value is! num || !value.isFinite || value.abs() > 1e12) {
      throw const FormatException();
    }
    return value.toDouble();
  }

  try {
    final costs = data['costs'];
    final rates = data['rates'];
    if (costs is! List ||
        costs.isEmpty ||
        costs.length > 100 ||
        rates is! Map) {
      throw const FormatException();
    }
    final result = const PricingCalculator().calculate(
      PricingInput(
        costs: costs.map((item) {
          if (item is! Map ||
              item['name'] is! String ||
              (item['name'] as String).length > 120) {
            throw const FormatException();
          }
          return PricingCost(
            name: item['name'] as String,
            quantity: number(item['quantity']),
            unitCost: number(item['unitCost']),
          );
        }).toList(),
        simplesNacionalRate: number(rates['simplesNacionalRate']),
        pisCofinsRate: number(rates['pisCofinsRate']),
        irCsllRate: number(rates['irCsllRate']),
        freightRate: number(rates['freightRate']),
        commissionRate: number(rates['commissionRate']),
        substitutionTaxRate: number(rates['substitutionTaxRate']),
        fixedExpenseRate: number(rates['fixedExpenseRate']),
        targetNetMarginRate: number(rates['targetNetMarginRate']),
        practicedPrice: data['practicedPrice'] == null
            ? null
            : number(data['practicedPrice']),
      ),
    );
    Map<String, double> statement(PricingIncomeStatement value) => {
      'revenue': value.revenue,
      'cmv': value.cmv,
      'variableExpenses': value.variableExpenses,
      'contributionMargin': value.contributionMargin,
      'contributionMarginRate': value.contributionMarginRate,
      'fixedExpenses': value.fixedExpenses,
      'netProfit': value.netProfit,
      'netMarginRate': value.netMarginRate,
    };
    final suggested = statement(result.suggested);
    final practiced = result.practiced == null
        ? null
        : statement(result.practiced!);
    if (![
      ...suggested.values,
      ...?practiced?.values,
      result.divisor,
      result.markupMultiplier,
    ].every((v) => v.isFinite)) {
      throw const FormatException();
    }
    return {
      'cmv': result.cmv,
      'divisor': result.divisor,
      'markupMultiplier': result.markupMultiplier,
      'suggested': suggested,
      'practiced': practiced,
    };
  } on ArgumentError {
    throw const ApiError(
      422,
      'invalid_pricing',
      'Confira os custos e percentuais. O CMV deve ser positivo e a soma das taxas com a margem deve ser menor que 100%.',
    );
  } on FormatException {
    throw const ApiError(
      422,
      'invalid_pricing',
      'Informe de 1 a 100 insumos, custos e percentuais numéricos válidos.',
    );
  }
}
