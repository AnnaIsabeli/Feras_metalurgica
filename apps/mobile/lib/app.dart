import 'package:flutter/material.dart';

import 'core/api_client.dart';
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
  Widget build(BuildContext context) => Scaffold(
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
                  onPressed: () => _open(context, false),
                  child: const Text('Demonstração: comprador'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _open(context, true),
                  child: const Text('Demonstração: vendedor'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  void _open(BuildContext context, bool seller) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AppShell(seller: seller)),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.seller});
  final bool seller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ApiClient api;
  late final QuoteViewModel quotes;
  int index = 0;
  @override
  void initState() {
    super.initState();
    api = ApiClient(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8080',
      ),
      token: widget.seller ? 'demo-seller' : 'demo-buyer',
    );
    quotes = QuoteViewModel(ApiQuoteRepository(api));
  }

  @override
  void dispose() {
    quotes.dispose();
    api.close();
    super.dispose();
  }

  void select(int value) {
    setState(() => index = value);
    if (value == 1) quotes.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
    body: switch (index) {
      0 => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.seller ? 'Olá, vendedor' : 'Olá, comprador',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text('Consulte e acompanhe suas solicitações de orçamento.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => select(1),
              child: const Text('Abrir orçamentos'),
            ),
          ],
        ),
      ),
      1 => QuoteScreen(model: quotes, seller: widget.seller),
      _ => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.seller
                ? 'Acompanhamento de pedidos será implementado na próxima etapa.'
                : 'Os canais de contato serão cadastrados na próxima etapa.',
          ),
        ),
      ),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: select,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Início',
        ),
        const NavigationDestination(
          icon: Icon(Icons.request_quote_outlined),
          label: 'Orçamentos',
        ),
        NavigationDestination(
          icon: Icon(
            widget.seller
                ? Icons.inventory_2_outlined
                : Icons.contact_support_outlined,
          ),
          label: widget.seller ? 'Pedidos' : 'Contato',
        ),
      ],
    ),
  );
}
