import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fera_contracts/fera_contracts.dart';
import '../core/user_profile.dart';
import 'quotes/quote_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.model,
    required this.seller,
    required this.onCreate,
    required this.onList,
    this.profile,
  });
  final QuoteViewModel model;
  final bool seller;
  final VoidCallback onCreate;
  final VoidCallback onList;
  final UserProfile? profile;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            profile == null || profile!.name.trim().isEmpty
                ? 'Olá!'
                : 'Olá, ${profile!.firstName}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: seller ? 'Criar orçamento' : 'Solicitar orçamento',
                  asset: 'assets/brand/action-add.svg',
                  onTap: onCreate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  label: 'Visualizar orçamentos',
                  asset: 'assets/brand/action-list.svg',
                  onTap: onList,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ListenableBuilder(
            listenable: model,
            builder: (context, _) {
              if (model.loading) return const LinearProgressIndicator();
              if (model.error != null) {
                return TextButton.icon(
                  onPressed: model.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar atualizar os orçamentos'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Últimos orçamentos',
                    style: TextStyle(fontSize: 14, color: Color(0xffc4bdb4)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final entry in {
                        RequestStatus.pending: 'Aguardando',
                        RequestStatus.inProduction: 'Produção',
                        RequestStatus.completed: 'Concluídos',
                      }.entries)
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 14,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    entry.value,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xffc4bdb4),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${model.items.where((q) => q.status == entry.key).length}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'Conheça um dos projetos da Fera Metalúrgica',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xffa9a39b)),
          ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 353 / 234,
                  child: LayoutBuilder(
                    builder: (context, box) => ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: box.maxWidth,
                        maxWidth: box.maxWidth,
                        minHeight: box.maxHeight * 2.3267,
                        maxHeight: box.maxHeight * 2.3267,
                        child: Transform.translate(
                          offset: Offset(
                            box.maxWidth * .0011,
                            -box.maxHeight * .8474,
                          ),
                          child: Image.asset(
                            'assets/brand/project-feature.png',
                            fit: BoxFit.fill,
                            width: box.maxWidth,
                            height: box.maxHeight * 2.3267,
                            semanticLabel:
                                'Mesa da Fera Metalúrgica com estrutura metálica e tampo de madeira',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.asset,
    required this.onTap,
  });
  final String label;
  final String asset;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xffff6d00),
                shape: BoxShape.circle,
              ),
              child: Center(child: SvgPicture.asset(asset)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
