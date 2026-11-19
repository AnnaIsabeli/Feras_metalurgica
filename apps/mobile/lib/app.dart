import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/orcex_theme.dart';
import 'features/home_screen.dart';
import 'features/auth/google_login_screen.dart';
import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/user_profile.dart';
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
    theme: orcexTheme(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const AccessScreen(),
  );
}

class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});
  static const _demo = bool.fromEnvironment('ENABLE_DEMO', defaultValue: false);
  @override
  Widget build(BuildContext context) => !_demo
      ? GoogleLoginScreen(
          onAuthenticated: (token, seller, profile) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AppShell(seller: seller, token: token, profile: profile),
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
  const AppShell({super.key, required this.seller, this.token, this.profile});
  final String? token;
  final UserProfile? profile;
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
      baseUrl: widget.token != null
          ? Uri.base.resolve('/api').toString()
          : const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8080',
            ),
      token: widget.token ?? (widget.seller ? 'demo-seller' : 'demo-buyer'),
    );
    quotes = QuoteViewModel(ApiQuoteRepository(api));
    quotes.load();
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
      automaticallyImplyLeading: false,
      leadingWidth: 76,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Image.asset(
          'assets/brand/header-logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Fera Metalúrgica',
        ),
      ),
      title: const Text('ORCEX'),
      actions: [
        IconButton(
          onPressed: () => select(2),
          tooltip: 'Minha conta',
          icon: ProfileAvatar(profile: widget.profile, size: 32),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: widget.token == null ? 'Sair da demonstração' : 'Sair',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: switch (index) {
      0 => HomeScreen(
        model: quotes,
        seller: widget.seller,
        profile: widget.profile,
        onList: () => select(1),
        onCreate: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => widget.seller
                ? PricingScreen(api: api, onSaved: quotes.load)
                : NewQuoteScreen(model: quotes),
          ),
        ),
      ),
      1 => QuoteScreen(model: quotes, seller: widget.seller, api: api),
      _ => AccountScreen(
        api: api,
        demonstration: widget.token == null,
        profile: widget.profile,
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
          icon: ProfileAvatar(profile: widget.profile, size: 26),
          label: 'Conta',
        ),
      ],
    ),
  );
}
