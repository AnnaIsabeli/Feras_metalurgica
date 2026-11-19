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
          const Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600),
              child: ProjectCarousel(),
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

class ProjectCarousel extends StatefulWidget {
  const ProjectCarousel({super.key});
  @override
  State<ProjectCarousel> createState() => _ProjectCarouselState();
}

class _ProjectCarouselState extends State<ProjectCarousel> {
  final _controller = PageController();
  int _page = 0;
  static const _labels = [
    'Mesa com estrutura metálica e tampo de madeira',
    'Suportes metálicos para plantas',
    'Mesa e estante com estrutura metálica',
  ];
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
    page,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: PageView.builder(
            controller: _controller,
            itemCount: _labels.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => Semantics(
              label: '${_labels[index]}. Imagem ${index + 1} de 3.',
              image: true,
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final imageHeight = box.maxWidth * 1844 / 853;
                    final fraction = [2 / 3, 0.0, 1 / 3][index];
                    return ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: imageHeight,
                        maxHeight: imageHeight,
                        child: Transform.translate(
                          offset: Offset(0, -imageHeight * fraction),
                          child: Image.asset(
                            'assets/brand/login-background.png',
                            width: box.maxWidth,
                            height: imageHeight,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          IconButton(
            tooltip: 'Imagem anterior',
            onPressed: _page == 0 ? null : () => _go(_page - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              _labels[_page],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xffc4bdb4)),
            ),
          ),
          IconButton(
            tooltip: 'Próxima imagem',
            onPressed: _page == 2 ? null : () => _go(_page + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _labels.length; i++)
            Semantics(
              selected: i == _page,
              child: IconButton(
                tooltip: 'Ver imagem ${i + 1}',
                onPressed: () => _go(i),
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? const Color(0xffff8a34)
                        : const Color(0xff77716b),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
