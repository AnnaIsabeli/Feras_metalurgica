import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with WidgetsBindingObserver {
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _role = 'seller';
  String? _session, _error, _notice, _setupUri, _manualKey;
  String? _pendingCommand;
  String? _commandPayload;
  DateTime? _expiresAt;
  Map<String, dynamic>? _data;
  bool _busy = false;
  Timer? _expiry;
  Map<String, String> get _headers => {'x-admin-session': _session!};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _clear({String? message}) {
    _expiry?.cancel();
    _session = null;
    _data = null;
    _expiresAt = null;
    _setupUri = null;
    _manualKey = null;
    _code.clear();
    _notice = message;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _expiresAt != null &&
        !DateTime.now().isBefore(_expiresAt!)) {
      setState(
        () => _clear(
          message: 'Sessão administrativa encerrada. Confirme um novo código.',
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    final session = _session;
    if (session != null) {
      unawaited(
        widget.api
            .post('/v1/admin/lock', {}, headers: {'x-admin-session': session})
            .then<void>((_) {})
            .catchError((Object _) {}),
      );
    }
    _code.dispose();
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted)
        setState(() {
          if (e is ApiException && e.code == 'admin_session_required') {
            _clear();
          }
          _error = e.toString();
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enroll() => _run(() async {
    final result = await widget.api.post('/v1/admin/enrollment', {});
    if (mounted)
      setState(() {
        _setupUri = result['otpauthUri'] as String;
        _manualKey = result['manualKey'] as String;
      });
  });
  Future<void> _unlock() => _run(() async {
    final result = await widget.api.post('/v1/admin/session', {
      'code': _code.text.trim(),
    });
    if (!mounted) return;
    _session = result['session'] as String;
    _code.clear();
    _setupUri = null;
    _manualKey = null;
    final duration = Duration(seconds: result['expiresIn'] as int);
    _expiresAt = DateTime.now().add(duration);
    _expiry?.cancel();
    _expiry = Timer(duration, () {
      if (mounted)
        setState(
          () => _clear(
            message:
                'Sessão administrativa encerrada. Confirme um novo código.',
          ),
        );
    });
    await _load();
  });
  Future<void> _load() async {
    final result = await widget.api.get(
      '/v1/admin/overview',
      headers: _headers,
    );
    if (mounted) setState(() => _data = result);
  }

  Future<void> _lock() => _run(() async {
    try {
      await widget.api.post('/v1/admin/lock', {}, headers: _headers);
    } finally {
      if (mounted) setState(() => _clear(message: 'Administração bloqueada.'));
    }
  });
  Future<void> _invite() async {
    if (_busy || !_form.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    final role = _role;
    final reason = _reason.text.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          role == 'admin' ? 'Convidar administrador?' : 'Autorizar vendedor?',
        ),
        content: Text(
          '$email\n\n${role == 'admin' ? 'Essa pessoa poderá autorizar vendedores e outros administradores após configurar seu autenticador.' : 'Essa pessoa poderá criar e precificar orçamentos após entrar com o Google.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar autorização'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final payload = '$email\n$role\n$reason';
    if (_commandPayload != payload) {
      _pendingCommand = const Uuid().v4();
      _commandPayload = payload;
    }
    await _run(() async {
      final result = await widget.api.post('/v1/admin/invitations', {
        'email': email,
        'role': role,
        'reason': reason,
        'commandId': _pendingCommand,
      }, headers: _headers);
      if (!mounted) return;
      _pendingCommand = null;
      _commandPayload = null;
      _email.clear();
      _reason.clear();
      _notice = result['status'] == 'approved'
          ? 'Vendedor autorizado. A pessoa deve sair e entrar novamente.'
          : 'Autorização registrada por 7 dias. A pessoa deve entrar com o Google usando esse e-mail${role == 'admin' ? ' e configurar o próprio autenticador' : ''}. Nenhum e-mail foi enviado automaticamente.';
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administração'),
      actions: [
        if (_session != null)
          IconButton(
            onPressed: _busy ? null : _lock,
            tooltip: 'Bloquear administração',
            icon: const Icon(Icons.lock_outline),
          ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
              if (_session == null) ...[
                const Icon(Icons.admin_panel_settings_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Confirme seu acesso',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sua conta Google precisa estar autorizada. Use o código do seu autenticador para liberar a administração por 5 minutos.',
                ),
                const SizedBox(height: 20),
                if (_setupUri != null) ...[
                  const Text(
                    'Adicione esta conta ao seu aplicativo autenticador. Não compartilhe a chave ou o QR code.',
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: QrImageView(
                      data: _setupUri!,
                      size: 220,
                      backgroundColor: Colors.white,
                      semanticsLabel:
                          'QR code para configurar seu autenticador pessoal',
                    ),
                  ),
                  ExpansionTile(
                    title: const Text('Digitar chave manualmente'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _manualKey!,
                          style: const TextStyle(letterSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _code,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código do autenticador',
                  ),
                  onSubmitted: (_) => _busy ? null : _unlock(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Desbloquear administração'),
                ),
                const SizedBox(height: 16),
                if (_setupUri == null)
                  OutlinedButton(
                    onPressed: _busy ? null : _enroll,
                    child: const Text(
                      'Primeiro acesso: configurar autenticador',
                    ),
                  ),
              ] else ...[
                Text(
                  'Gerenciar acessos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vendedor e administrador são permissões distintas. Autorize apenas os acessos necessários.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Autorizar por e-mail',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            maxLength: 254,
                            decoration: const InputDecoration(
                              labelText: 'E-mail da conta Google',
                            ),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(value.trim())
                                ? 'Informe um e-mail válido.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            decoration: const InputDecoration(
                              labelText: 'Acesso',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'seller',
                                child: Text('Vendedor'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Administrador'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _role = value!),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _reason,
                            maxLength: 240,
                            decoration: const InputDecoration(
                              labelText: 'Motivo da autorização',
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 8
                                ? 'Descreva o motivo com ao menos 8 caracteres.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy ? null : _invite,
                            child: const Text('Revisar autorização'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contas cadastradas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => _run(_load),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Atualizar acessos',
                    ),
                  ],
                ),
                for (final raw in (_data?['users'] as List? ?? [])) ...[
                  Card(
                    child: ListTile(
                      title: Text((raw as Map)['display_name'] as String),
                      subtitle: Text(
                        '${raw['email']}\n${raw['admin_eligible'] == true ? 'Administrador autorizado • ' : ''}${raw['role'] == 'seller' && raw['seller_approved'] == true ? 'Vendedor aprovado' : 'Cliente'}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Autorizações recentes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final raw in (_data?['invitations'] as List? ?? []))
                  Card(
                    child: ListTile(
                      title: Text((raw as Map)['email'] as String),
                      subtitle: Text(
                        '${raw['role'] == 'admin' ? 'Administrador' : 'Vendedor'} • ${raw['accepted_by'] == null ? 'Aguardando primeiro acesso' : 'Vinculada à conta'}',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Histórico de segurança',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final raw in (_data?['audit'] as List? ?? []))
                  ListTile(
                    title: Text(_actionLabel((raw as Map)['action'] as String)),
                    subtitle: Text(
                      '${raw['actor_email'] ?? 'Provisionamento inicial'}${raw['target_email'] == null ? '' : ' → ${raw['target_email']}'}\n${raw['reason'] ?? ''}\n${_date(raw['created_at'] as String)}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  String _date(String text) {
    final d = DateTime.parse(text).toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _actionLabel(String action) => switch (action) {
    'mfa_activated' => 'Autenticador confirmado',
    'session_opened' => 'Administração desbloqueada',
    'mfa_rejected' => 'Tentativa de autenticação recusada',
    'seller_approved' => 'Vendedor autorizado',
    'seller_invited' => 'Vendedor convidado',
    'admin_invited' => 'Administrador convidado',
    'seller_revoked' => 'Acesso de vendedor revogado',
    'invitation_cancelled' => 'Convite cancelado',
    _ => 'Alteração administrativa',
  };
}
