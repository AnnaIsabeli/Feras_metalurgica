import 'dart:convert';
import 'dart:io';
import '../lib/src/pricing/pricing_calculator.dart';
import '../lib/src/pricing/pricing_input.dart';
import '../lib/src/pricing/pricing_result.dart';

int checks = 0;
void check(bool ok, String message) {
  if (!ok) throw StateError(message);
  checks++;
}

void main() {
  const calc = PricingCalculator();
  final fixture = jsonDecode(
    File('test/fixtures/pricing_workbook.json').readAsStringSync(),
  );
  for (final c in fixture['cases']) {
    final costs = <PricingCost>[
      for (final x in c['costs'])
        PricingCost(
          name: x['name'],
          quantity: (x['quantity'] as num).toDouble(),
          unitCost: x['purchaseCost'] / x['purchaseQuantity'],
        ),
    ];
    final r = c['rates'];
    PricingInput build({double? fixed, double? margin, double? price}) =>
        PricingInput(
          costs: costs,
          simplesNacionalRate: (r['simplesNacionalRate'] as num).toDouble(),
          pisCofinsRate: (r['pisCofinsRate'] as num).toDouble(),
          irCsllRate: (r['irCsllRate'] as num).toDouble(),
          freightRate: (r['freightRate'] as num).toDouble(),
          commissionRate: (r['commissionRate'] as num).toDouble(),
          substitutionTaxRate: (r['substitutionTaxRate'] as num).toDouble(),
          fixedExpenseRate: fixed ?? (r['fixedExpenseRate'] as num).toDouble(),
          targetNetMarginRate:
              margin ?? (r['targetNetMarginRate'] as num).toDouble(),
          practicedPrice: price ?? (c['practicedPrice'] as num).toDouble(),
        );
    final result = calc.calculate(build());
    void verify(PricingIncomeStatement s, dynamic expected) {
      final values = {
        'revenue': s.revenue,
        'cmv': s.cmv,
        'variableExpenses': s.variableExpenses,
        'contributionMargin': s.contributionMargin,
        'contributionMarginRate': s.contributionMarginRate,
        'fixedExpenses': s.fixedExpenses,
        'netProfit': s.netProfit,
        'netMarginRate': s.netMarginRate,
      };
      for (final e in values.entries) {
        check(
          (e.value - expected[e.key]).abs() < .00001,
          '${c['name']} ${e.key}: ${e.value} != ${expected[e.key]}',
        );
      }
    }

    verify(result.suggested, c['suggested']);
    verify(result.practiced!, c['practiced']);
    for (final bad in [
      build(fixed: .5, margin: .5),
      build(margin: double.nan),
      build(price: 0),
      build(fixed: -1),
      build(margin: 4.5),
    ]) {
      var rejected = false;
      try {
        calc.calculate(bad);
      } on ArgumentError {
        rejected = true;
      }
      check(rejected, 'invalid input accepted');
    }
    print('PASS ${c['name']}');
  }
  print('$checks checks passed');
}
