import 'package:flutter/material.dart';
import 'package:fera_contracts/fera_contracts.dart';

import 'material_view_model.dart';

String formatCost(String cost, String unit) =>
    'R\$ ${cost.replaceAll('.', ',')} / $unit';

/// Catálogo de materiais. Administrador (model.canManage) cadastra, edita e
/// ativa/desativa; vendedor aprovado só consulta os materiais ativos. A API
/// aplica a mesma regra: esconder botões aqui não é a proteção.
class MaterialScreen extends StatefulWidget {
  const MaterialScreen({super.key, required this.model});
  final MaterialViewModel model;
  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm([CatalogMaterial? material]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          MaterialFormScreen(model: widget.model, material: material),
    ),
  );

  Future<void> _confirmStatus(CatalogMaterial material, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Desativar material?'),
          content: Text(
            '“${material.name}” deixará de aparecer para novas composições. ' 
            'O registro e os custos históricos serão preservados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Desativar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final saved = await widget.model.setActive(material, active);
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(active ? 'Material reativado.' : 'Material desativado.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    model.canManage ? 'Catálogo de materiais' : 'Materiais ativos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: model.loading ? null : () => model.load(),
                  tooltip: 'Atualizar',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Pesquisar por nome ou unidade',
                suffixIcon: IconButton(
                  tooltip: 'Pesquisar',
                  icon: const Icon(Icons.search),
                  onPressed: () => model.load(query: _search.text),
                ),
              ),
              onSubmitted: (value) => model.load(query: value),
            ),
          ),
          if (model.canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (final (value, label) in const [
                    ('all', 'Todos'),
                    ('active', 'Ativos'),
                    ('inactive', 'Inativos'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: model.status == value,
                        onSelected: (_) => model.load(status: value),
                      ),
                    ),
                ],
              ),
            ),
          if (model.canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar material'),
                ),
              ),
            ),
          if (model.loading) const LinearProgressIndicator(),
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(model.error!, key: const Key('materialError')),
            ),
          Expanded(
            child: model.items.isEmpty
                ? Center(
                    child: Text(
                      model.error != null
                          ? 'Tente atualizar novamente.'
                          : model.loading
                          ? 'Carregando…'
                          : 'Nenhum material encontrado.',
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
                          title: Text(item.name),
                          subtitle: Text(
                            '${formatCost(item.unitCost, item.unit)}'
                            '${item.active ? '' : ' • Inativo'}',
                          ),
                          trailing: model.canManage
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openForm(item),
                                    ),
                                    Switch(
                                      value: item.active,
                                      onChanged: model.loading
                                          ? null
                                          : (v) => _confirmStatus(item, v),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MaterialFormScreen extends StatefulWidget {
  const MaterialFormScreen({super.key, required this.model, this.material});
  final MaterialViewModel model;
  final CatalogMaterial? material;
  @override
  State<MaterialFormScreen> createState() => _MaterialFormScreenState();
}

class _MaterialFormScreenState extends State<MaterialFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.material?.name);
  late final _unit = TextEditingController(text: widget.material?.unit);
  late final _cost = TextEditingController(
    text: widget.material?.unitCost.replaceAll('.', ','),
  );

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final success = await widget.model.save(
      id: widget.material?.id,
      name: _name.text.trim(),
      unit: _unit.text.trim(),
      // A API recebe decimal com ponto; a tela aceita vírgula.
      unitCost: _cost.text.trim().replaceAll(',', '.'),
    );
    if (!mounted || !success) return;
    Navigator.pop(context);
    await widget.model.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.material == null ? 'Cadastrar material' : 'Editar material'),
    ),
    body: ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unit,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Unidade (ex.: metro, kg)'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe a unidade.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custo unitário (R\$)',
                helperText: 'Até 6 casas decimais. Ex.: 13,333333',
              ),
              validator: (v) =>
                  RegExp(r'^\d{1,8}([.,]\d{1,6})?$').hasMatch((v ?? '').trim())
                  ? null
                  : 'Informe um valor não negativo, com até 6 casas decimais.',
            ),
            const SizedBox(height: 24),
            if (widget.model.error != null) Text(widget.model.error!),
            FilledButton(
              onPressed: widget.model.loading ? null : _submit,
              child: Text(widget.model.loading ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
      ),
    ),
  );
}
