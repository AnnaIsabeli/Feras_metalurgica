import 'features/auth/google_login_screen.dart';
import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'features/materials/material_repository.dart';
import 'features/materials/material_screen.dart';
import 'features/materials/material_view_model.dart';
import 'features/pricing/pricing_screen.dart';
import 'features/account_screen.dart';
import 'features/quotes/quote_repository.dart';
import 'features/quotes/quote_screen.dart';
import 'features/quotes/quote_view_model.dart';

class FeraApp extends StatelessWidget {
  const FeraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fera Metalúrgica',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffff7800),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff363431),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xffff7800),
          foregroundColor: Colors.black,
          minimumSize: const Size(0, 48),
        ),
      ),
    ),
    home: const AccessScreen(),
  );
}

class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});
  static const _demo = bool.fromEnvironment('ENABLE_DEMO', defaultValue: false);
  @override
  Widget build(BuildContext context) => !_demo
      ? GoogleLoginScreen(
          onAuthenticated: (token, seller) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AppShell(seller: seller, token: token),
              ),
            );
          },
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Fera Metalúrgica')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bem-vindo ao ORCEX',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _demo
                          ? 'Demonstração local • acesso Google ainda não integrado.'
                          : 'O acesso com Google será disponibilizado na próxima etapa.',
                    ),
                    if (_demo) ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => _open(context, 'demo-buyer'),
                        child: const Text('Demonstração: cliente'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _open(context, 'demo-seller'),
                        child: const Text('Demonstração: vendedor aprovado'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _open(context, 'demo-seller-pending'),
                        child: const Text('Demonstração: vendedor pendente'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _open(context, 'demo-admin'),
                        child: const Text('Demonstração: administrador'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
  void _open(BuildContext context, String token) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AppShell(seller: token == 'demo-seller', token: token),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.seller, this.token});
  final String? token;
  final bool seller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ApiClient api;
  late final QuoteViewModel quotes;
  MaterialViewModel? materials;
  Session? session;
  String? sessionError;
  bool loadingSession = true;
  int index = 0;

  @override
  void initState() {
    super.initState();
    api = ApiClient(
      baseUrl: widget.token != null && !widget.token!.startsWith('demo-')
          ? Uri.base.resolve('/api').toString()
          : const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8080',
            ),
      token: widget.token ?? (widget.seller ? 'demo-seller' : 'demo-buyer'),
    );
    quotes = QuoteViewModel(ApiQuoteRepository(api));
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final loaded = Session.fromJson(await api.get('/v1/me'));
      if (!mounted) return;
      setState(() {
        session = loaded;
        materials = loaded.can('readMaterials')
            ? MaterialViewModel(
                ApiMaterialRepository(api),
                canManage: loaded.can('writeMaterials'),
              )
            : null;
        loadingSession = false;
      });
      if (loaded.can('listQuotes')) quotes.load();
      if (loaded.can('readMaterials')) materials?.load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        sessionError = e.toString();
        loadingSession = false;
      });
    }
  }

  @override
  void dispose() {
    quotes.dispose();
    materials?.dispose();
    api.close();
    super.dispose();
  }

  List<String> get _tabs {
    final s = session;
    if (s == null) return const [];
    return [
      'Início',
      if (s.can('listQuotes')) 'Orçamentos',
      if (s.can('readMaterials')) (s.can('writeMaterials') ? 'Catálogo' : 'Materiais'),
      'Conta',
    ];
  }

  void _select(int value) {
    setState(() => index = value);
    final tab = _tabs[value];
    if (tab == 'Orçamentos') quotes.load();
    if (tab == 'Catálogo' || tab == 'Materiais') materials?.load();
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORCEX'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: widget.token == null ? 'Sair da demonstração' : 'Sair',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loadingSession
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(sessionError ?? 'Não foi possível identificar o acesso.'),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: () { setState(() { loadingSession = true; sessionError = null; }); _loadSession(); }, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _buildBody(s),
      bottomNavigationBar: s == null || _tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index.clamp(0, _tabs.length - 1).toInt(),
              onDestinationSelected: _select,
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(switch (tab) {
                      'Início' => Icons.home_outlined,
                      'Orçamentos' => Icons.request_quote_outlined,
                      'Catálogo' || 'Materiais' => Icons.category_outlined,
                      _ => Icons.account_circle_outlined,
                    }),
                    label: tab,
                  ),
              ],
            ),
    );
  }

  Widget _buildBody(Session s) {
    final tab = _tabs[index.clamp(0, _tabs.length - 1).toInt()];
    if (tab == 'Orçamentos') {
      return QuoteScreen(
        model: quotes,
        seller: s.role == 'seller' && s.sellerApproved,
        api: api,
        canCreate: s.can('createQuote'),
        title: s.role == 'admin' ? 'Solicitações' : null,
      );
    }
    if (tab == 'Catálogo' || tab == 'Materiais') {
      return MaterialScreen(model: materials!);
    }
    if (tab == 'Conta') {
      return AccountScreen(api: api, demonstration: widget.token == null || widget.token!.startsWith('demo-'));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Olá, ${s.roleLabel}', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(s.isPendingSeller
                ? 'Seu acesso de vendedor ainda não foi aprovado.'
                : switch (s.role) {
                    'admin' => 'Gerencie o catálogo e acompanhe as solicitações.',
                    'seller' => 'Consulte materiais ativos e prepare a precificação.',
                    _ => 'Consulte e acompanhe suas solicitações de orçamento.',
                  }),
            if (s.can('listQuotes')) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _select(_tabs.indexOf('Orçamentos')),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Abrir orçamentos'),
              ),
            ],
            if (s.role == 'seller' && s.sellerApproved) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => PricingScreen(api: api)),
                ),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Simular preço de venda'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
