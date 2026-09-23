import 'dart:convert';
import 'dart:io';

import 'package:fera_api/src/pricing/pricing_calculator.dart';
import 'package:fera_api/src/pricing/pricing_input.dart';
import 'package:fera_api/src/pricing/pricing_result.dart';
import 'package:test/test.dart';

PricingInput input({
  List<PricingCost>? costs,
  Map<String, double> rates = const {},
  double? practicedPrice,
}) => PricingInput(
  costs:
      costs ??
      [const PricingCost(name: 'Material', quantity: 1, unitCost: 100)],
  simplesNacionalRate: rates['simplesNacionalRate'] ?? 0,
  pisCofinsRate: rates['pisCofinsRate'] ?? 0,
  irCsllRate: rates['irCsllRate'] ?? 0,
  freightRate: rates['freightRate'] ?? 0,
  commissionRate: rates['commissionRate'] ?? 0,
  substitutionTaxRate: rates['substitutionTaxRate'] ?? 0,
  fixedExpenseRate: rates['fixedExpenseRate'] ?? 0,
  targetNetMarginRate: rates['targetNetMarginRate'] ?? 0,
  practicedPrice: practicedPrice,
);

void expectStatement(
  PricingIncomeStatement actual,
  Map<String, dynamic> expected,
) {
  final values = {
    'revenue': actual.revenue,
    'cmv': actual.cmv,
    'variableExpenses': actual.variableExpenses,
    'contributionMargin': actual.contributionMargin,
    'contributionMarginRate': actual.contributionMarginRate,
    'fixedExpenses': actual.fixedExpenses,
    'netProfit': actual.netProfit,
    'netMarginRate': actual.netMarginRate,
  };
  for (final entry in values.entries) {
    // Workbook export caches approximately ten significant digits.
    expect(
      entry.value,
      closeTo(expected[entry.key] as num, 0.00001),
      reason: entry.key,
    );
  }
}

void main() {
  const calculator = PricingCalculator();
  final fixture =
      jsonDecode(File('test/fixtures/pricing_workbook.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final sample in fixture['cases'] as List) {
    test('workbook: ${sample['name']}', () {
      final costs = (sample['costs'] as List)
          .map(
            (c) => PricingCost(
              name: c['name'] as String,
              quantity: (c['quantity'] as num).toDouble(),
              unitCost:
                  (c['purchaseCost'] as num) / (c['purchaseQuantity'] as num),
            ),
          )
          .toList();
      final rates = (sample['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
      final result = calculator.calculate(
        input(
          costs: costs,
          rates: rates,
          practicedPrice: (sample['practicedPrice'] as num).toDouble(),
        ),
      );
      expectStatement(
        result.suggested,
        sample['suggested'] as Map<String, dynamic>,
      );
      expectStatement(
        result.practiced!,
        sample['practiced'] as Map<String, dynamic>,
      );
      expect(
        result.suggested.netMarginRate,
        closeTo(rates['targetNetMarginRate']!, 1e-12),
      );
      expect(result.markupMultiplier * result.divisor, closeTo(1, 1e-12));
    });
  }

  test('zero percentages preserve CMV and omit practiced statement', () {
    final result = calculator.calculate(input());
    expect(result.cmv, 100);
    expect(result.suggestedPrice, 100);
    expect(result.suggested.netProfit, 0);
    expect(result.practiced, isNull);
  });
  test('all variable taxes participate, fixed expenses remain separate', () {
    final result = calculator.calculate(
      input(
        rates: {
          'simplesNacionalRate': .01,
          'pisCofinsRate': .02,
          'irCsllRate': .03,
          'freightRate': .04,
          'commissionRate': .05,
          'substitutionTaxRate': .06,
          'fixedExpenseRate': .09,
          'targetNetMarginRate': .20,
        },
      ),
    );
    expect(result.suggestedPrice, closeTo(200, 1e-10));
    expect(result.suggested.variableExpenses, closeTo(42, 1e-10));
    expect(result.suggested.contributionMargin, closeTo(58, 1e-10));
    expect(result.suggested.fixedExpenses, closeTo(18, 1e-10));
    expect(result.suggested.netProfit, closeTo(40, 1e-10));
  });
  test('preserves fractional unit costs without intermediate rounding', () {
    final result = calculator.calculate(
      input(
        costs: [PricingCost(name: 'Barra', quantity: 6, unitCost: 22 / 6)],
      ),
    );
    expect(result.cmv, closeTo(22, 1e-12));
  });
  test('negotiated price may result in a loss', () {
    expect(
      calculator.calculate(input(practicedPrice: 50)).practiced!.netProfit,
      -50,
    );
  });
  for (final margin in [.5, .6]) {
    test('rejects zero or negative divisor: $margin', () {
      expect(
        () => calculator.calculate(
          input(rates: {'fixedExpenseRate': .5, 'targetNetMarginRate': margin}),
        ),
        throwsArgumentError,
      );
    });
  }
  for (final field in [
    'simplesNacionalRate',
    'pisCofinsRate',
    'irCsllRate',
    'freightRate',
    'commissionRate',
    'substitutionTaxRate',
    'fixedExpenseRate',
    'targetNetMarginRate',
  ]) {
    for (final bad in [-.1, 4.5, double.nan, double.infinity]) {
      test('rejects invalid $field: $bad', () {
        expect(
          () => calculator.calculate(input(rates: {field: bad})),
          throwsArgumentError,
        );
      });
    }
  }
  for (final bad in [-1.0, double.nan, double.infinity]) {
    test('rejects invalid cost or quantity: $bad', () {
      for (final cost in [
        PricingCost(name: 'x', quantity: bad, unitCost: 1),
        PricingCost(name: 'x', quantity: 1, unitCost: bad),
      ]) {
        expect(
          () => calculator.calculate(input(costs: [cost])),
          throwsArgumentError,
        );
      }
    });
  }
  for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
    test('rejects invalid practiced price: $bad', () {
      expect(
        () => calculator.calculate(input(practicedPrice: bad)),
        throwsArgumentError,
      );
    });
  }
  test('rejects missing, unnamed, zero and overflowing costs', () {
    for (final costs in <List<PricingCost>>[
      [],
      [const PricingCost(name: ' ', quantity: 1, unitCost: 100)],
      [const PricingCost(name: 'x', quantity: 0, unitCost: 100)],
      [const PricingCost(name: 'x', quantity: 1e308, unitCost: 1e308)],
    ]) {
      expect(
        () => calculator.calculate(input(costs: costs)),
        throwsArgumentError,
      );
    }
  });
  test('input snapshots its cost list', () {
    final costs = [const PricingCost(name: 'x', quantity: 1, unitCost: 100)];
    final value = input(costs: costs);
    costs.clear();
    expect(calculator.calculate(value).cmv, 100);
    expect(() => value.costs.clear(), throwsUnsupportedError);
  });
}
