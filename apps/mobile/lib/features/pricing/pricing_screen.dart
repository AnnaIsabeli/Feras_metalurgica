import 'package:flutter/material.dart';

import '../../core/api_client.dart';

const pricingRates = <String, String>{
  'simplesNacionalRate': 'Simples Nacional',
  'pisCofinsRate': 'PIS / COFINS',
  'irCsllRate': 'IR / CSLL',
  'freightRate': 'Frete',
  'commissionRate': 'Comissão',
  'substitutionTaxRate': 'Substituição tributária',
  'fixedExpenseRate': 'Despesas fixas',
  'targetNetMarginRate': 'Margem líquida desejada',
};

double? parseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
String money(num value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

class _CostFields {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitCost = TextEditingController();
  void dispose() {
    name.dispose();
    quantity.dispose();
    unitCost.dispose();
  }
}

class PricingScreen extends StatefulWidget {
  const PricingScreen({
    super.key,
    required this.api,
    this.product,
    this.quantity = 1,
  });
  final ApiClient api;
  final String? product;
  final int quantity;
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final _form = GlobalKey<FormState>();
  final _costs = [_CostFields()];
  final _rates = {
    for (final key in pricingRates.keys) key: TextEditingController(text: '0'),
  };
  final _practiced = TextEditingController();
  Map<String, dynamic>? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final cost in _costs) {
      cost.dispose();
    }
    for (final rate in _rates.values) {
      rate.dispose();
    }
    _practiced.dispose();
    super.dispose();
  }

  void _changed() {
    if (_result != null || _error != null) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  String? _number(String? text, {bool percent = false, bool optional = false}) {
    if (optional && (text ?? '').trim().isEmpty) return null;
    final value = parseDecimal(text ?? '');
    return value == null ||
            !value.isFinite ||
            value < 0 ||
            value > (percent ? 100 : 1e12)
        ? (percent
              ? 'Use um percentual de 0 a 100.'
              : 'Informe um número positivo ou zero, sem separador de milhar.')
        : null;
  }

  Future<void> _calculate() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Revise os campos destacados antes de calcular.');
      return;
    }
    final rateTotal = _rates.values.fold<double>(
      0,
      (sum, field) => sum + parseDecimal(field.text)!,
    );
    if (rateTotal >= 100) {
      setState(
        () => _error = 'A soma dos percentuais, incluindo a margem, deve ser menor que 100%.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.api.post('/v1/pricing/calculate', {
        'costs': [
          for (final cost in _costs)
            {
              'name': cost.name.text.trim(),
              'quantity': parseDecimal(cost.quantity.text),
              'unitCost': parseDecimal(cost.unitCost.text),
            },
        ],
        'rates': {
          for (final rate in _rates.entries)
            rate.key: parseDecimal(rate.value.text)! / 100,
        },
        if (_practiced.text.trim().isNotEmpty)
          'practicedPrice': parseDecimal(_practiced.text),
      });
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _decimal(
    TextEditingController controller,
    String label, {
    bool percent = false,
    bool optional = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      suffixText: percent ? '%' : null,
    ),
    validator: (value) => _number(value, percent: percent, optional: optional),
  );

  Widget _statement(String title, Map<String, dynamic> value) {
    final profit = (value['netProfit'] as num).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              money(value['revenue'] as num),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text('Preço por unidade do produto'),
            if (widget.quantity > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total para ${widget.quantity} unidades: ${money((value['revenue'] as num) * widget.quantity)}',
                ),
              ),
            const Divider(height: 32),
            for (final entry in {
              'cmv': 'Custo dos materiais (CMV)',
              'variableExpenses': 'Despesas variáveis',
              'contributionMargin': 'Margem de contribuição',
              'fixedExpenses': 'Despesas fixas',
              'netProfit': 'Lucro líquido',
            }.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  children: [
                    Text(entry.value),
                    Text(money(value[entry.key] as num)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Margem líquida: ${((value['netMarginRate'] as num) * 100).toStringAsFixed(2).replaceAll('.', ',')}%',
            ),
            Text(
              'Contribuição: ${((value['contributionMarginRate'] as num) * 100).toStringAsFixed(2).replaceAll('.', ',')}%',
            ),
            if (profit < 0)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Atenção: este preço gera prejuízo.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Precificar orçamento')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Form(
          key: _form,
          onChanged: _changed,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.product ?? 'Simulação de preço',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Informe os materiais necessários para uma unidade do produto. Use a mesma unidade de medida na quantidade e no custo unitário.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Simulação: o cálculo não salva nem envia uma proposta ao comprador.',
                ),
                const SizedBox(height: 24),
                AbsorbPointer(
                  absorbing: _busy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '1. Materiais e custos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final cost in _costs)
                        Card(
                          key: ObjectKey(cost),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Insumo ${_costs.indexOf(cost) + 1}',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remover insumo',
                                      onPressed: _costs.length == 1
                                          ? null
                                          : () {
                                              setState(() {
                                                _costs.remove(cost);
                                                _result = null;
                                              });
                                              cost.dispose();
                                            },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                TextFormField(
                                  controller: cost.name,
                                  maxLength: 120,
                                  decoration: const InputDecoration(
                                    labelText: 'Material e unidade (ex.: Metalon / metro)',
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Informe o material.'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final fields = [
                                      _decimal(
                                        cost.quantity,
                                        'Quantidade consumida',
                                      ),
                                      _decimal(
                                        cost.unitCost,
                                        'Custo por unidade (R\$)',
                                      ),
                                    ];
                                    return constraints.maxWidth < 480
                                        ? Column(
                                            children: [
                                              fields[0],
                                              const SizedBox(height: 16),
                                              fields[1],
                                            ],
                                          )
                                        : Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: fields[0]),
                                              const SizedBox(width: 16),
                                              Expanded(child: fields[1]),
                                            ],
                                          );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _costs.length >= 100
                            ? null
                            : () => setState(() {
                                _costs.add(_CostFields());
                                _result = null;
                              }),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar material'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '2. Impostos, despesas e margem',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Preencha os percentuais do seu cenário. Exemplo: 4,5 significa 4,5%.',
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final entry in pricingRates.entries)
                              SizedBox(
                                width: constraints.maxWidth < 560
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 16) / 2,
                                child: _decimal(
                                  _rates[entry.key]!,
                                  entry.value,
                                  percent: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '3. Negociação (opcional)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _decimal(
                        _practiced,
                        'Preço negociado por produto (R\$)',
                        optional: true,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : _calculate,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(_busy ? 'Calculando…' : 'Calcular preço'),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _statement(
                    'Preço sugerido',
                    _result!['suggested'] as Map<String, dynamic>,
                  ),
                  if (_result!['practiced'] != null)
                    _statement(
                      'Preço negociado',
                      _result!['practiced'] as Map<String, dynamic>,
                    ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
