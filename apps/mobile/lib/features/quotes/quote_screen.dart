import 'package:flutter/material.dart';
import 'package:fera_contracts/fera_contracts.dart';

import 'quote_view_model.dart';

class QuoteScreen extends StatelessWidget {
  const QuoteScreen({super.key, required this.model, required this.seller});
  final QuoteViewModel model;
  final bool seller;

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
                  seller ? 'Solicitações recebidas' : 'Meus orçamentos',
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
        if (!seller)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NewQuoteScreen(model: model),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Solicitar orçamento'),
            ),
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
                        : 'Nenhuma solicitação por enquanto.',
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
                          '${item.quantity} unidade(s) • ${_statusLabel(item.status)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(item.product),
                            content: SingleChildScrollView(
                              child: Text(
                                '${item.description}\n\nQuantidade: ${item.quantity}\nSituação: ${_statusLabel(item.status)}',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fechar'),
                              ),
                            ],
                          ),
                        ),
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
  RequestStatus.received => 'Recebida',
  RequestStatus.needsInformation => 'Aguardando informações',
  RequestStatus.drafting => 'Em elaboração',
  RequestStatus.quoted => 'Proposta enviada',
  RequestStatus.closed => 'Encerrada',
};

class NewQuoteScreen extends StatefulWidget {
  const NewQuoteScreen({super.key, required this.model});
  final QuoteViewModel model;
  @override
  State<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends State<NewQuoteScreen> {
  final _form = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  @override
  void dispose() {
    _product.dispose();
    _description.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final success = await widget.model.submit(
      _product.text.trim(),
      _description.text.trim(),
      int.parse(_quantity.text),
    );
    if (!mounted || !success) return;
    Navigator.pop(context);
    await widget.model.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Solicitar orçamento')),
    body: ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _product,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Produto'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o produto.' : null,
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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Descreva seu pedido.' : null,
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
                widget.model.loading ? 'Enviando…' : 'Enviar solicitação',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
