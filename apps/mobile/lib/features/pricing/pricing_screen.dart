import 'package:fera_contracts/fera_contracts.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import 'quote_pdf_actions.dart';

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

/// Número para exibir em um campo: vírgula decimal e sem zeros sobrando
/// (4.5 vira "4,5"; 100.0 vira "100").
String formatDecimal(num value) => value
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '')
    .replaceAll('.', ',');

/// Quantas casas decimais o texto digitado tem ("2,125" -> 3).
int decimalPlaces(String text) {
  final clean = text.trim().replaceAll(',', '.');
  final dot = clean.indexOf('.');
  return dot < 0 ? 0 : clean.length - dot - 1;
}

String _two(int n) => n.toString().padLeft(2, '0');
String dateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// Material do catálogo, como devolvido por GET /v1/materials.
class CatalogMaterial {
  const CatalogMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitCost,
  });
  final String id;
  final String name;
  final String unit;
  final double unitCost;

  factory CatalogMaterial.fromJson(Map<String, dynamic> json) =>
      CatalogMaterial(
        id: json['id'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        unitCost: (json['unitCost'] as num).toDouble(),
      );

  String get label => '$name / $unit';
}

const _manualOption = '__manual__';

/// Uma linha da composição. Ou vem do catálogo ([material]) ou é digitada
/// à mão ([manual]); enquanto nenhuma das duas, o vendedor ainda não escolheu.
class _CostFields {
  CatalogMaterial? material;
  bool manual = false;
  final name = TextEditingController();
  final unit = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitCost = TextEditingController();
  void dispose() {
    name.dispose();
    unit.dispose();
    quantity.dispose();
    unitCost.dispose();
  }
}

class PricingScreen extends StatefulWidget {
  const PricingScreen({
    super.key,
    required this.api,
    this.request,
    this.pdfActions = const SystemQuotePdfActions(),
  });
  final QuotePdfActions pdfActions;
  final ApiClient api;

  /// Solicitação que está sendo precificada. Nula na simulação avulsa
  /// (nesse caso não há o que salvar).
  final QuoteRequest? request;
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
  final _deliveryLeadTime = TextEditingController();
  String? _savedPricingId;
  bool _dirty = false;
  bool _exportingPdf = false;
  List<CatalogMaterial> _materials = const [];
  Map<String, dynamic>? _result;
  DateTime? _savedAt;
  String? _error;
  String? _notice;
  String? _loadError;
  bool _loading = true;
  bool _busy = false;
  bool _saving = false;

  String? get _product => widget.request?.product;
  int get _quantity => widget.request?.quantity ?? 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final cost in _costs) {
      cost.dispose();
    }
    for (final rate in _rates.values) {
      rate.dispose();
    }
    _practiced.dispose();
    _deliveryLeadTime.dispose();
    super.dispose();
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Algo deu errado. Tente novamente.';

  /// Última precificação salva da solicitação, ou null se ainda não existe.
  /// "Ainda não existe" (404) é normal, não é erro.
  Future<Map<String, dynamic>?> _latestPricing(String requestId) async {
    try {
      return await widget.api.get('/v1/quote-requests/$requestId/pricing');
    } on ApiException catch (e) {
      if (e.status == 404 && e.code == 'pricing_not_found') return null;
      rethrow;
    }
  }

  Future<void> _load() async {
    try {
      final requestId = widget.request?.id;
      final responses = await Future.wait<Map<String, dynamic>?>([
        widget.api.get('/v1/materials'),
        if (requestId != null) _latestPricing(requestId),
      ]);
      final materials = [
        for (final item in responses[0]!['items'] as List)
          CatalogMaterial.fromJson(item as Map<String, dynamic>),
      ];
      final saved = responses.length > 1 ? responses[1] : null;
      if (!mounted) return;
      setState(() {
        _materials = materials;
        if (saved != null) _restore(saved);
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = _message(e);
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  /// Preenche a tela com a precificação salva (o que veio do servidor).
  void _restore(Map<String, dynamic> saved) {
    _savedAt = DateTime.tryParse(saved['createdAt'] as String? ?? '');
    final input = saved['input'] as Map<String, dynamic>?;
    final result = saved['result'] as Map<String, dynamic>?;
    if (input == null || result == null) {
      // Registro antigo, sem os detalhes: não inventamos um cálculo.
      _notice =
          'Esta solicitação tem uma precificação antiga, sem os detalhes. '
          'Monte a composição novamente e salve.';
      return;
    }
    _savedPricingId = saved['id'] as String?;
    _dirty = false;
    final delivery = input['deliveryLeadTime'];
    _deliveryLeadTime.text = delivery is String ? delivery : '';
    final rows = <_CostFields>[];
    for (final item in (input['costs'] as List).cast<Map<String, dynamic>>()) {
      final row = _CostFields();
      final inCatalog = _materials.where((m) => m.id == item['materialId']);
      if (inCatalog.isNotEmpty) {
        row.material = inCatalog.first;
      } else {
        // Digitado à mão, ou material que saiu do catálogo: usa o que foi salvo.
        row.manual = true;
        row.name.text = item['name'] as String;
        row.unit.text = item['unit'] as String? ?? '';
        row.unitCost.text = formatDecimal(item['unitCost'] as num);
      }
      row.quantity.text = formatDecimal(item['quantity'] as num);
      rows.add(row);
    }
    for (final old in _costs) {
      old.dispose();
    }
    _costs
      ..clear()
      ..addAll(rows);
    final rates = input['rates'] as Map<String, dynamic>;
    for (final key in pricingRates.keys) {
      _rates[key]!.text = formatDecimal((rates[key] as num) * 100);
    }
    final practiced = input['practicedPrice'] as num?;
    _practiced.text = practiced == null ? '' : formatDecimal(practiced);
    _result = result;
  }

  void _changed() {
    if (!_dirty || _result != null || _error != null || _notice != null) {
      setState(() {
        _dirty = true;
        _result = null;
        _error = null;
        _notice = null;
      });
    }
  }

  Future<void> _exportPdf({required bool download}) async {
    final request = widget.request;
    final revision = _savedPricingId;
    if (request == null || revision == null || _dirty || _busy || _exportingPdf)
      return;
    setState(() {
      _exportingPdf = true;
      _error = null;
      _notice = null;
    });
    try {
      final file = await widget.api.getPdf(
        '/v1/quote-requests/${request.id}/pdf'
        '?pricingId=${Uri.encodeQueryComponent(revision)}${download ? '&download=1' : ''}',
      );
      if (!mounted) return;
      final completed = download
          ? await widget.pdfActions.download(file)
          : await widget.pdfActions.preview(file);
      if (mounted)
        setState(() => _notice = completed ? 'PDF pronto.' : 'Ação cancelada.');
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
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

  // Mesmas regras que a API aplica ao salvar (ela continua sendo a palavra final).
  String? _quantityError(String? text) {
    final base = _number(text);
    if (base != null) return base;
    final value = parseDecimal(text!)!;
    if (value <= 0) return 'A quantidade deve ser maior que zero.';
    if (value > 999999999.999) return 'Quantidade alta demais.';
    if (decimalPlaces(text) > 3) return 'Use no máximo 3 casas decimais.';
    return null;
  }

  String? _costError(String? text) {
    final base = _number(text);
    if (base != null) return base;
    if (parseDecimal(text!)! > 99999999.999999) return 'Custo alto demais.';
    if (decimalPlaces(text) > 6) return 'Use no máximo 6 casas decimais.';
    return null;
  }

  String? _percentError(String? text) => _number(text, percent: true);
  String? _optionalMoneyError(String? text) => _number(text, optional: true);

  bool _validate() {
    if (!_form.currentState!.validate()) {
      setState(
        () => _error = 'Revise os campos destacados antes de continuar.',
      );
      return false;
    }
    final rateTotal = _rates.values.fold<double>(
      0,
      (sum, field) => sum + parseDecimal(field.text)!,
    );
    if (rateTotal >= 100) {
      setState(
        () => _error =
            'A soma dos percentuais, incluindo a margem, deve ser menor que 100%.',
      );
      return false;
    }
    return true;
  }

  Map<String, double> get _ratesBody => {
    for (final rate in _rates.entries)
      rate.key: parseDecimal(rate.value.text)! / 100,
  };

  double? get _practicedPrice =>
      _practiced.text.trim().isEmpty ? null : parseDecimal(_practiced.text);

  /// Simulação: o servidor calcula, nada é salvo.
  Future<void> _calculate() async {
    if (_busy || _exportingPdf || !_validate()) return;
    setState(() {
      _busy = true;
      _saving = false;
      _error = null;
      _notice = null;
      _result = null;
    });
    final practiced = _practicedPrice;
    try {
      final result = await widget.api.post('/v1/pricing/calculate', {
        'costs': [
          for (final cost in _costs)
            {
              'name': cost.material?.name ?? cost.name.text.trim(),
              'quantity': parseDecimal(cost.quantity.text),
              'unitCost':
                  cost.material?.unitCost ?? parseDecimal(cost.unitCost.text),
            },
        ],
        'rates': _ratesBody,
        'practicedPrice': ?practiced,
      });
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// O servidor calcula de novo, grava no PostgreSQL e devolve o resultado.
  Future<void> _save() async {
    final request = widget.request;
    if (request == null || _busy || _exportingPdf || !_validate()) return;
    setState(() {
      _busy = true;
      _saving = true;
      _error = null;
      _notice = null;
      _result = null;
    });
    final practiced = _practicedPrice;
    try {
      final saved = await widget.api.post(
        '/v1/quote-requests/${request.id}/pricing',
        {
          'costs': [
            for (final cost in _costs)
              if (cost.material case final material?)
                // Do catálogo: só o id e a quantidade; nome, unidade e
                // custo o servidor busca por conta própria.
                {
                  'materialId': material.id,
                  'quantity': parseDecimal(cost.quantity.text),
                }
              else
                {
                  'name': cost.name.text.trim(),
                  'unit': cost.unit.text.trim(),
                  'quantity': parseDecimal(cost.quantity.text),
                  'unitCost': parseDecimal(cost.unitCost.text),
                },
          ],
          'rates': _ratesBody,
          'practicedPrice': ?practiced,
          'deliveryLeadTime': _deliveryLeadTime.text.trim().isEmpty
              ? null
              : _deliveryLeadTime.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _result = saved['result'] as Map<String, dynamic>?;
        _savedPricingId = saved['id'] as String?;
        _dirty = false;
        _savedAt = DateTime.tryParse(saved['createdAt'] as String? ?? '');
        _notice =
            'Precificação salva. Ela continuará aqui quando você reabrir esta solicitação.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _decimal(
    TextEditingController controller,
    String label, {
    required String? Function(String?) validator,
    String? suffix,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: validator,
  );

  Widget _costCard(_CostFields cost, int index) {
    final material = cost.material;
    final quantityField = _decimal(
      cost.quantity,
      material == null
          ? 'Quantidade consumida'
          : 'Quantidade (${material.unit})',
      validator: _quantityError,
    );
    final Widget costField = cost.manual
        ? _decimal(
            cost.unitCost,
            'Custo por unidade (R\$)',
            validator: _costError,
          )
        : InputDecorator(
            decoration: InputDecoration(
              labelText: material == null
                  ? 'Custo por unidade'
                  : 'Custo por ${material.unit} (catálogo)',
            ),
            child: Text(material == null ? '—' : money(material.unitCost)),
          );
    return Card(
      key: ObjectKey(cost),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Insumo ${index + 1}')),
                IconButton(
                  tooltip: 'Remover insumo',
                  onPressed: _costs.length == 1
                      ? null
                      : () {
                          setState(() {
                            _costs.remove(cost);
                            _dirty = true;
                            _result = null;
                            _notice = null;
                          });
                          cost.dispose();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: cost.manual ? _manualOption : material?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Material'),
              items: <DropdownMenuItem<String>>[
                for (final item in _materials)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(
                  value: _manualOption,
                  child: Text('Outro material (digitar)'),
                ),
              ],
              validator: (value) =>
                  value == null ? 'Escolha um material.' : null,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  cost.manual = value == _manualOption;
                  cost.material = cost.manual
                      ? null
                      : _materials.firstWhere((m) => m.id == value);
                  _dirty = true;
                  _result = null;
                  _notice = null;
                });
              },
            ),
            if (cost.manual) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: cost.name,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nome do material (ex.: Metalon)',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Informe o material.'
                    : null,
              ),
              TextFormField(
                controller: cost.unit,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Unidade (ex.: metro, kg)',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe a unidade.' : null,
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 480
                  ? Column(
                      children: [
                        quantityField,
                        const SizedBox(height: 16),
                        costField,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: quantityField),
                        const SizedBox(width: 16),
                        Expanded(child: costField),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(QuoteRequest request) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dados da solicitação',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(request.description),
          const SizedBox(height: 8),
          Text('${request.quantity} unidade(s)'),
          Text('Solicitada em ${dateTime(request.createdAt.toLocal())}'),
          SelectableText('Referência: ${request.id}'),
        ],
      ),
    ),
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
            if (_quantity > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total para $_quantity unidades: ${money((value['revenue'] as num) * _quantity)}',
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

  Widget _loadFailure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );

  Widget _content() {
    final request = widget.request;
    return Center(
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
                  _product ?? 'Simulação de preço',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (request != null) ...[
                  _requestCard(request),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Escolha os materiais necessários para uma unidade do produto e informe a quantidade consumida de cada um.',
                ),
                const SizedBox(height: 8),
                Text(
                  request == null
                      ? 'Simulação avulsa: nada é salvo.'
                      : 'Calcular é só uma simulação. Use Salvar para guardar a precificação desta solicitação; isso não envia proposta ao comprador.',
                ),
                if (_savedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Última precificação salva em ${dateTime(_savedAt!.toLocal())}.',
                  ),
                ],
                const SizedBox(height: 24),
                AbsorbPointer(
                  absorbing: _busy || _exportingPdf,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '1. Materiais e custos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_materials.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'O catálogo ainda não tem materiais. Use "Outro material (digitar)".',
                          ),
                        ),
                      for (var i = 0; i < _costs.length; i++)
                        _costCard(_costs[i], i),
                      OutlinedButton.icon(
                        onPressed: _costs.length >= 100
                            ? null
                            : () => setState(() {
                                _costs.add(_CostFields());
                                _dirty = true;
                                _result = null;
                                _notice = null;
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
                                  validator: _percentError,
                                  suffix: '%',
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
                        validator: _optionalMoneyError,
                      ),
                      if (request != null) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _deliveryLeadTime,
                          maxLength: 240,
                          decoration: const InputDecoration(
                            labelText: 'Prazo de entrega (opcional)',
                            helperText:
                                'Preencha o prazo combinado para este orçamento.',
                          ),
                          validator: (text) =>
                              (text ?? '').length > 240 ||
                                  RegExp(
                                    r'[\x00-\x1f\x7f]',
                                  ).hasMatch(text ?? '')
                              ? 'Use até 240 caracteres, em uma linha.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_notice!),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || _exportingPdf ? null : _calculate,
                      icon: _busy && !_saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate_outlined),
                      label: Text(
                        _busy && !_saving ? 'Calculando…' : 'Calcular preço',
                      ),
                    ),
                    if (request != null)
                      FilledButton.tonalIcon(
                        onPressed: _busy || _exportingPdf ? null : _save,
                        icon: _busy && _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _busy && _saving
                              ? 'Salvando…'
                              : 'Salvar precificação',
                        ),
                      ),
                  ],
                ),
                if (request != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _savedPricingId == null
                        ? 'Salve a precificação para liberar o PDF.'
                        : _dirty
                        ? 'Salve as alterações para atualizar e liberar o PDF.'
                        : 'PDF da precificação salva. Custos internos e margens não aparecem no documento.',
                  ),
                  if (_exportingPdf)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('previewQuotePdf'),
                        onPressed:
                            _savedPricingId == null ||
                                _dirty ||
                                _busy ||
                                _exportingPdf
                            ? null
                            : () => _exportPdf(download: false),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Visualizar / imprimir PDF'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('downloadQuotePdf'),
                        onPressed:
                            _savedPricingId == null ||
                                _dirty ||
                                _busy ||
                                _exportingPdf
                            ? null
                            : () => _exportPdf(download: true),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Baixar / compartilhar PDF'),
                      ),
                    ],
                  ),
                ],
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
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Precificar orçamento')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? _loadFailure()
        : _content(),
  );
}
