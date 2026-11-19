import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'features/materials/material_repository.dart';
import 'features/materials/material_screen.dart';
import 'features/materials/material_view_model.dart';
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

/// Contas de DEMONSTRAÇÃO LOCAL. Os tokens só são aceitos pela API com
/// APP_ENV=development e DEV_AUTH_ENABLED=true; o botão só aparece com
/// --dart-define=ENABLE_DEMO=true. Não é a autenticação final.
const demoAccounts = <(String, String)>[
  ('Cliente', 'demo-buyer'),
  ('Outro cliente', 'demo-buyer-2'),
  ('Vendedor', 'demo-seller'),
  ('Vendedor não aprovado', 'demo-seller-pending'),
  ('Administrador', 'demo-admin'),
];

class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});
  static const _demo = bool.fromEnvironment('ENABLE_DEMO', defaultValue: false);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fera Metalúrgica')),
    body: Center(
      child: SingleChildScrollView(
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
                if (_demo)
                  for (final (label, token) in demoAccounts) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _open(context, token),
                      child: Text('Demonstração: ${label.toLowerCase()}'),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  void _open(BuildContext context, String token) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AppShell(token: token)),
  );
}

enum _Tab { home, quotes, materials, orders, contact }

/// Casca do aplicativo. As abas dependem das permissões devolvidas por
/// `/v1/me`; a API continua sendo quem autoriza cada operação.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.token, this.api});
  final String token;

  /// Permite injetar um cliente (testes). Em uso normal é criado a partir do token.
  final ApiClient? api;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ApiClient api;
  late final QuoteViewModel quotes;
  MaterialViewModel? materials;
  Session? session;
  String? error;
  bool loadingSession = true;
  int index = 0;

  @override
  void initState() {
    super.initState();
    api =
        widget.api ??
        ApiClient(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8080',
          ),
          token: widget.token,
        );
    quotes = QuoteViewModel(ApiQuoteRepository(api));
    _loadSession();
  }

  void _retry() {
    setState(() {
      loadingSession = true;
      error = null;
    });
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
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

  List<_Tab> get tabs {
    final s = session;
    if (s == null) return const [];
    return [
      _Tab.home,
      if (s.can('listQuotes')) _Tab.quotes,
      if (s.can('readMaterials')) _Tab.materials,
      if (s.role == 'seller' && s.sellerApproved) _Tab.orders,
      if (s.role == 'buyer') _Tab.contact,
    ];
  }

  int get _current => index < tabs.length ? index : 0;

  void select(int value) {
    setState(() => index = value);
    final tab = tabs[value];
    if (tab == _Tab.quotes) quotes.load();
    if (tab == _Tab.materials) materials?.load();
  }

  void _openTab(_Tab tab) {
    final position = tabs.indexOf(tab);
    if (position >= 0) select(position);
  }

  NavigationDestination _destination(_Tab tab, Session s) => switch (tab) {
    _Tab.home => const NavigationDestination(
      icon: Icon(Icons.home_outlined),
      label: 'Início',
    ),
    _Tab.quotes => const NavigationDestination(
      icon: Icon(Icons.request_quote_outlined),
      label: 'Orçamentos',
    ),
    _Tab.materials => NavigationDestination(
      icon: const Icon(Icons.category_outlined),
      label: s.can('writeMaterials') ? 'Catálogo' : 'Materiais',
    ),
    _Tab.orders => const NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'Pedidos',
    ),
    _Tab.contact => const NavigationDestination(
      icon: Icon(Icons.contact_support_outlined),
      label: 'Contato',
    ),
  };

  String _homeText(Session s) {
    if (s.isPendingSeller) {
      return 'Seu acesso de vendedor ainda não foi aprovado. Peça a um administrador para liberar.';
    }
    return switch (s.role) {
      'admin' =>
        'Gerencie o catálogo de materiais e acompanhe as solicitações.',
      'seller' => 'Consulte as solicitações e os materiais para compor orçamentos.',
      _ => 'Consulte e acompanhe suas solicitações de orçamento.',
    };
  }

  Widget _body(Session s) {
    final tab = tabs[_current];
    return switch (tab) {
      _Tab.home => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, ${s.roleLabel}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(_homeText(s)),
            if (s.can('listQuotes')) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _openTab(_Tab.quotes),
                child: const Text('Abrir orçamentos'),
              ),
            ],
          ],
        ),
      ),
      _Tab.quotes => QuoteScreen(model: quotes, canCreate: s.can('createQuote')),
      _Tab.materials => MaterialScreen(model: materials!),
      _Tab.orders => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Acompanhamento de pedidos será implementado na próxima etapa.'),
        ),
      ),
      _Tab.contact => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Os canais de contato serão cadastrados na próxima etapa.'),
        ),
      ),
    };
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
            tooltip: 'Sair da demonstração',
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
                    Text(error ?? 'Não foi possível identificar o acesso.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : _body(s),
      bottomNavigationBar: s == null || tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _current,
              onDestinationSelected: select,
              destinations: [for (final t in tabs) _destination(t, s)],
            ),
    );
  }
}
