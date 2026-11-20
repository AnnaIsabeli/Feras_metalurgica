import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Figma Login 68:10; authentication remains in GoogleLoginScreen.
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
  static const orange = Color(0xffff6d00);

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: Brightness.dark,
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xff24221f),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final inset = MediaQuery.paddingOf(context);
          final compact = constraints.maxWidth < 600;
          final height = math.max(0.0, constraints.maxHeight - inset.vertical);
          final markSize = (height * .18).clamp(88.0, 144.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/brand/login-background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                excludeFromSemantics: true,
              ),
              if (!compact)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x55000000),
                        Color(0x11000000),
                        Color(0x55000000),
                      ],
                    ),
                  ),
                ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0.0, height - 48),
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 393,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: markSize,
                              child: const FittedBox(child: _FeraMark()),
                            ),
                            const SizedBox(height: 24),
                            _entry(),
                            const SizedBox(height: 24),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: _AccessFooter(),
                            ),
                            const SizedBox(height: 16),
                          ],
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

  Widget _entry() => Container(
    width: 278,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
    decoration: BoxDecoration(
      color: const Color(0xa6000000),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: orange, width: 3)),
          ),
          child: const Text(
            'Entrar no ORCEX',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: Center(
            child: busy || !ready && error == null
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: orange,
                    ),
                  )
                : signInButton ??
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: Colors.white70,
                      ),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Conferindo seu acesso…',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xffffc6a6),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Preserve the original source image and the crop supplied by Figma 262:59.
class _FeraMark extends StatelessWidget {
  const _FeraMark();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fera Metalúrgica',
    image: true,
    child: SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xb3000000),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: -4,
            top: 28,
            width: 208,
            height: 143,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 731.432,
                maxWidth: 731.432,
                minHeight: 520,
                maxHeight: 520,
                child: Transform.translate(
                  offset: const Offset(-261.7056, -117),
                  child: Image.asset(
                    'assets/brand/fera-mark-source.png',
                    width: 731.432,
                    height: 520,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccessFooter extends StatelessWidget {
  const _AccessFooter();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xb3000000),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Prefere pedir pelo WhatsApp?\nO cliente não precisa criar uma conta.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xfff3ede6)),
        ),
        SizedBox(height: 8),
        SelectableText(
          'orcex.shop/privacidade.html  •  orcex.shop/termos.html',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, height: 1.5, color: Color(0xffd8cec2)),
        ),
      ],
    ),
  );
}
