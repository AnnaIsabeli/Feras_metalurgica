import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/api_client.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key, required this.onAuthenticated});
  final Future<void> Function(String token, bool seller) onAuthenticated;
  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  static Future<void>? initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? subscription;
  bool ready = false;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(initialize());
  }

  Future<void> initialize() async {
    try {
      await (initialization ??= GoogleSignIn.instance.initialize(
        clientId: const String.fromEnvironment(
          'GOOGLE_WEB_CLIENT_ID',
          defaultValue:
              '965632441479-ivdt904eif0bh4202ntiua0vn1blj8av.apps.googleusercontent.com',
        ),
      ));
      if (!mounted) return;
      subscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn)
            unawaited(enter(event.user));
        },
        onError: (Object _) {
          if (mounted)
            setState(() {
              error = 'Não foi possível entrar com Google. Tente novamente.';
              busy = false;
            });
        },
      );
      setState(() => ready = true);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Não foi possível carregar o login. Atualize a página e tente novamente.',
        );
    }
  }

  Future<void> enter(GoogleSignInAccount user) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    ApiClient? api;
    Timer? expiry;
    try {
      final token = user.authentication.idToken;
      if (token == null)
        throw const ApiException(
          'O Google não devolveu uma identificação válida.',
        );
      api = ApiClient(
        baseUrl: Uri.base.resolve('/api').toString(),
        token: token,
      );
      final me = await api.get('/v1/me');
      if (!mounted) return;
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      final remaining =
          DateTime.fromMillisecondsSinceEpoch(
            (claims['exp'] as int) * 1000,
          ).difference(DateTime.now()) -
          const Duration(seconds: 30);
      if (remaining.isNegative)
        throw const ApiException('Sessão expirada. Entre novamente.');
      expiry = Timer(remaining, () {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
      await widget.onAuthenticated(
        token,
        me['role'] == 'seller' && me['sellerApproved'] == true,
      );
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is ApiException
              ? e.message
              : 'Não foi possível concluir o acesso. Tente novamente.',
        );
    } finally {
      expiry?.cancel();
      api?.close();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        /* Session remains memory-only. */
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.precision_manufacturing_outlined,
                size: 58,
                color: Color(0xffff7800),
              ),
              const SizedBox(height: 24),
              Text(
                'ORCEX',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Do pedido ao orçamento.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Entre com sua conta Google para acessar seu atendimento. O acesso da equipe depende das permissões autorizadas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!ready && error == null || busy)
                const LinearProgressIndicator(),
              if (ready && !busy) Center(child: googleButton()),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              const Text(
                'Não precisa criar uma conta para pedir um orçamento: você também pode continuar o atendimento diretamente com a equipe pelo WhatsApp.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const SelectableText(
                'Privacidade: orcex.shop/privacidade.html\nTermos: orcex.shop/termos.html',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
