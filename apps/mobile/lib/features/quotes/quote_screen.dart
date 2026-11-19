import 'package:flutter/material.dart';
import 'package:fera_contracts/fera_contracts.dart';

import 'quote_view_model.dart';
import '../../core/api_client.dart';
import '../pricing/pricing_screen.dart';

class QuoteScreen extends StatelessWidget {
  const QuoteScreen({
    super.key,
    required this.model,
    required this.seller,
    required this.api,
  });
  final QuoteViewModel model;
  final bool seller;
  final ApiClient api;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  seller ? 'Orçamentos' : 'Meus orçamentos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: model.loading ? null : model.load,
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => seller
                    ? PricingScreen(api: api, onSaved: model.load)
                    : NewQuoteScreen(model: model),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(seller ? 'Criar orçamento' : 'Solicitar orçamento'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _QuoteFilters(model: model, seller: seller),
        ),
        if (model.loading) const LinearProgressIndicator(),
        if (model.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(model.error!, key: const Key('quoteError')),
          ),
        Expanded(
          child: model.items.isEmpty
              ? Center(
                  child: Text(
                    model.error != null
                        ? 'Tente atualizar novamente.'
                        : model.loading
                        ? 'Carregando…'
                        : 'Nenhum orçamento neste filtro.',
                  ),
                )
              : ListView.builder(
                  itemCount: model.items.length,
                  itemBuilder: (context, index) {
                    final item = model.items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(item.product),
                        subtitle: Text(
                          '${item.customerName ?? 'Cliente'} • ${item.createdAt.toLocal().day}/${item.createdAt.toLocal().month}/${item.createdAt.toLocal().year}\n${_statusLabel(item.status)}${item.unitPriceCents == null ? '' : ' • ${money(item.unitPriceCents! * item.quantity / 100)}'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => QuoteDetailScreen(
                                item: item,
                                seller: seller,
                                api: api,
                              ),
                            ),
                          );
                          await model.load();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

String _statusLabel(RequestStatus status) => switch (status) {
  RequestStatus.received => 'A precificar',
  RequestStatus.needsInformation => 'Aguardando informações',
  RequestStatus.drafting => 'Em elaboração',
  RequestStatus.quoted => 'Proposta enviada',
  RequestStatus.closed => 'Encerrada',
  RequestStatus.pending => 'Aguardando aprovação',
  RequestStatus.approved => 'Aprovado',
  RequestStatus.rejected => 'Recusado',
  RequestStatus.inProduction => 'Em produção',
  RequestStatus.completed => 'Concluído',
  RequestStatus.cancelled => 'Cancelado',
};

class NewQuoteScreen extends StatefulWidget {
  const NewQuoteScreen({super.key, required this.model, this.seller = false});
  final bool seller;
  final QuoteViewModel model;
  @override
  State<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends State<NewQuoteScreen> {
  final _form = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _customerName = TextEditingController();
  final _customerContact = TextEditingController();
  @override
  void dispose() {
    _product.dispose();
    _description.dispose();
    _quantity.dispose();
    _customerName.dispose();
    _customerContact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final success = await widget.model.submit(
      _product.text.trim(),
      _description.text.trim(),
      int.parse(_quantity.text),
      customerName: widget.seller ? _customerName.text.trim() : null,
      customerContact: widget.seller ? _customerContact.text.trim() : null,
    );
    if (!mounted || !success) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.seller
              ? 'Orçamento criado. Abra-o para precificar.'
              : 'Solicitação enviada com sucesso.',
        ),
      ),
    );
    await widget.model.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.seller ? 'Criar orçamento' : 'Solicitar orçamento'),
    ),
    body: ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.seller) ...[
                    const Text(
                      'Cadastre o pedido recebido pelo WhatsApp ou em outro atendimento. O cliente não precisa de uma conta.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _customerName,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nome do cliente',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Informe o nome do cliente.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _customerContact,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Contato do cliente (opcional)',
                        helperText:
                            'Telefone, WhatsApp ou e-mail para retorno.',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: _product,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Produto'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o produto.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do pedido',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Descreva seu pedido.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 10000
                          ? 'Informe um número inteiro de 1 a 10000.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (widget.model.error != null) Text(widget.model.error!),
                  FilledButton(
                    onPressed: widget.model.loading ? null : _submit,
                    child: Text(
                      widget.model.loading
                          ? 'Salvando…'
                          : widget.seller
                          ? 'Criar orçamento'
                          : 'Enviar solicitação',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class QuoteDetailScreen extends StatefulWidget {
  const QuoteDetailScreen({
    super.key,
    required this.item,
    required this.seller,
    required this.api,
  });
  final QuoteRequest item;
  final bool seller;
  final ApiClient api;
  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  late QuoteRequest item = widget.item;
  bool _busy = false;
  String? _error;
  Future<void> _refresh() async {
    try {
      final data = await widget.api.get('/v1/quote-requests/${item.id}');
      if (mounted) setState(() => item = QuoteRequest.fromJson(data));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _status(String target) async {
    final label = _statusLabel(RequestStatus.values.byName(target));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atualizar orçamento'),
        content: Text('Alterar o status para “$label”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.post(
        '/v1/quote-requests/${item.id}/status',
        {'status': target, 'expectedStatus': item.status.name},
      );
      if (mounted) setState(() => item = QuoteRequest.fromJson(data));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> get _next => switch (item.status) {
    RequestStatus.pending =>
      widget.seller
          ? ['approved', 'rejected', 'cancelled']
          : ['approved', 'rejected'],
    RequestStatus.approved =>
      widget.seller ? ['inProduction', 'cancelled'] : [],
    RequestStatus.inProduction =>
      widget.seller ? ['completed', 'cancelled'] : [],
    RequestStatus.rejected => widget.seller ? ['cancelled'] : [],
    _ => [],
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Orçamento'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              item.product,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                Chip(label: Text(_statusLabel(item.status))),
                Chip(label: Text('${item.quantity} unidade(s)')),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              item.customerName ?? 'Cliente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (item.customerContact != null)
              SelectableText(item.customerContact!),
            const SizedBox(height: 16),
            Text(item.description),
            if (item.unitPriceCents != null) ...[
              const SizedBox(height: 24),
              Text(
                'Total: ${money(item.unitPriceCents! * item.quantity / 100)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Valor unitário: ${money(item.unitPriceCents! / 100)}'),
            ],
            const SizedBox(height: 24),
            Text('Criado em ${dateTime(item.createdAt.toLocal())}'),
            SelectableText('Referência: ${item.id}'),
            const SizedBox(height: 24),
            if (widget.seller)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PricingScreen(api: widget.api, request: item),
                          ),
                        );
                        await _refresh();
                      },
                icon: const Icon(Icons.request_quote_outlined),
                label: Text(
                  item.pricingId == null
                      ? 'Compor e salvar orçamento'
                      : 'Composição e PDF',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_next.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Andamento', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final target in _next)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _status(target),
                      child: Text(
                        _statusLabel(RequestStatus.values.byName(target)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _QuoteFilters extends StatefulWidget {
  const _QuoteFilters({required this.model, required this.seller});
  final QuoteViewModel model;
  final bool seller;
  @override
  State<_QuoteFilters> createState() => _QuoteFiltersState();
}

class _QuoteFiltersState extends State<_QuoteFilters> {
  final _customer = TextEditingController();
  DateTimeRange? _range;
  String? _statusValue;
  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void _apply() => widget.model.load(
    filters: {
      if (_customer.text.trim().isNotEmpty) 'customer': _customer.text.trim(),
      if (_range != null) 'from': _day(_range!.start),
      if (_range != null) 'to': _day(_range!.end),
      'status': ?_statusValue,
    },
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.seller)
        TextField(
          controller: _customer,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Filtrar por cliente',
            prefixIcon: Icon(Icons.search),
            counterText: '',
          ),
          onSubmitted: (_) => _apply(),
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.model.loading
                  ? null
                  : () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2050),
                        initialDateRange: _range,
                      );
                      if (range != null && mounted) {
                        setState(() => _range = range);
                      }
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _range == null
                    ? 'Data'
                    : '${_range!.start.day}/${_range!.start.month}–${_range!.end.day}/${_range!.end.month}',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey(_statusValue),
              initialValue: _statusValue,
              hint: const Text('Todos'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final s in [
                  RequestStatus.received,
                  RequestStatus.pending,
                  RequestStatus.approved,
                  RequestStatus.rejected,
                  RequestStatus.inProduction,
                  RequestStatus.completed,
                  RequestStatus.cancelled,
                ])
                  DropdownMenuItem(
                    value: s.name,
                    child: Text(
                      _statusLabel(s),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: widget.model.loading
                  ? null
                  : (value) => setState(() => _statusValue = value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: widget.model.loading ? null : _apply,
              child: const Text('Filtrar'),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: widget.model.loading
                ? null
                : () {
                    _customer.clear();
                    setState(() {
                      _range = null;
                      _statusValue = null;
                    });
                    widget.model.load(filters: const {});
                  },
            child: const Text('Limpar'),
          ),
        ],
      ),
    ],
  );
}
