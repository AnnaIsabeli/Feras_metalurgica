import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Presentation only: identity and account permissions remain in the login controller.
class LoginPresentation extends StatelessWidget {
  const LoginPresentation({
    super.key,
    required this.ready,
    required this.busy,
    required this.error,
    required this.signInButton,
  });

  final bool ready;
  final bool busy;
  final String? error;
  final Widget? signInButton;
  static const orange = Color(0xfff47b29);
  static const charcoal = Color(0xff252420);

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: Brightness.dark,
        surface: charcoal,
      ),
      scaffoldBackgroundColor: charcoal,
    ),
    child: Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Original Figma photography will be supplied after asset export.
              Image.asset(
                'assets/brand/login-background.jpg',
                fit: BoxFit.cover,
                alignment: desktop ? Alignment.centerLeft : Alignment.center,
                excludeFromSemantics: true,
                errorBuilder: (_, error, stack) =>
                    const ColoredBox(color: charcoal),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: desktop ? Alignment.centerLeft : Alignment.topCenter,
                    end: desktop
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    colors: const [Color(0x66201c18), Color(0xee201e1a)],
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: desktop ? 64 : 24,
                    vertical: desktop ? 40 : 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0.0,
                        constraints.maxHeight - (desktop ? 80 : 56),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: desktop
                            ? Row(
                                children: [
                                  const Expanded(child: _BrandIntroduction()),
                                  const SizedBox(width: 72),
                                  SizedBox(width: 420, child: _entryPanel()),
                                ],
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: Column(
                                  children: [
                                    const _BrandMark(),
                                    const SizedBox(height: 40),
                                    _entryPanel(),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _entryPanel() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xed292824),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0x24ffffff)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 48,
          offset: Offset(0, 20),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 36,
            height: 4,
            child: ColoredBox(color: orange),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Seu próximo projeto\ncomeça aqui.',
          style: TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Entre com sua conta Google para acessar seus orçamentos.',
          style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xffc7c3bb)),
        ),
        const SizedBox(height: 28),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xff35332d),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x44f47b29)),
          ),
          child: Center(
            child: busy || !ready && error == null
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: orange,
                    ),
                  )
                : signInButton ??
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: Color(0xffc7c3bb),
                      ),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const Text(
            'Conferindo seu acesso…',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xffc7c3bb)),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xffffb4ab), height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(color: Color(0x24ffffff)),
        const SizedBox(height: 16),
        const Text(
          'Prefere falar com a equipe?',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Você pode pedir seu orçamento pelo WhatsApp, sem criar conta ou instalar o aplicativo.',
          style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xffb8b3aa)),
        ),
        const SizedBox(height: 24),
        const SelectableText(
          'Privacidade: orcex.shop/privacidade.html\nTermos: orcex.shop/termos.html',
          style: TextStyle(fontSize: 11, height: 1.8, color: Color(0xff9f9b93)),
        ),
      ],
    ),
  );
}

class _BrandIntroduction extends StatelessWidget {
  const _BrandIntroduction();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _BrandMark(),
      SizedBox(height: 80),
      Text(
        'Feito para tirar\nideias do papel.',
        style: TextStyle(
          fontSize: 52,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 24),
      SizedBox(
        width: 370,
        child: Text(
          'Do primeiro pedido ao orçamento.\nA experiência da Fera Metalúrgica,\ncom a praticidade do ORCEX.',
          style: TextStyle(fontSize: 18, height: 1.7, color: Color(0xffdfd9ce)),
        ),
      ),
    ],
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Image.asset(
        'assets/brand/fera-mark.png',
        width: 96,
        height: 96,
        fit: BoxFit.contain,
        semanticLabel: 'Fera Metalúrgica',
        errorBuilder: (_, error, stack) =>
            const SizedBox(width: 96, height: 96),
      ),
      const SizedBox(height: 16),
      const Text(
        'ORCEX',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          letterSpacing: 6,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
