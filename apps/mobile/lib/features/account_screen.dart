import 'package:flutter/material.dart';
import 'admin/admin_screen.dart';

import '../core/api_client.dart';
import '../core/user_profile.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.api,
    this.demonstration = true,
    this.profile,
  });
  final bool demonstration;
  final UserProfile? profile;
  final ApiClient api;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Map<String, dynamic>> _profile;
  @override
  void initState() {
    super.initState();
    _profile = widget.api.get('/v1/me');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Minha conta',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              if (snapshot.hasError) ...[
                Text(snapshot.error.toString()),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      setState(() => _profile = widget.api.get('/v1/me')),
                  child: const Text('Tentar novamente'),
                ),
              ] else ...[
                Center(
                  child: ProfileAvatar(profile: widget.profile, size: 144),
                ),
                const SizedBox(height: 24),
                if (widget.profile != null) ...[
                  TextFormField(
                    style: const TextStyle(color: Color(0xfff2f2f7)),
                    initialValue: widget.profile!.name,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      fillColor: Color(0xff2c2c2e),
                      labelStyle: TextStyle(color: Color(0xffffa261)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    style: const TextStyle(color: Color(0xfff2f2f7)),
                    initialValue: widget.profile!.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      fillColor: Color(0xff2c2c2e),
                      labelStyle: TextStyle(color: Color(0xffffa261)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (snapshot.data!['adminEligible'] == true) ...[
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminScreen(api: widget.api),
                      ),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Administração'),
                  ),
                  const SizedBox(height: 16),
                ],
                ListTile(
                  title: const Text('Tipo de acesso'),
                  subtitle: Text(
                    snapshot.data!['adminEligible'] == true
                        ? (snapshot.data!['role'] == 'seller'
                              ? 'Administrador · Vendedor'
                              : 'Administrador')
                        : snapshot.data!['role'] == 'seller'
                        ? 'Vendedor'
                        : 'Comprador',
                  ),
                ),
                if (snapshot.data!['role'] == 'seller')
                  ListTile(
                    title: const Text('Aprovação'),
                    subtitle: Text(
                      snapshot.data!['sellerApproved'] == true
                          ? 'Aprovado para atendimento e precificação'
                          : 'Aguardando aprovação',
                    ),
                  ),
                const Divider(),
                Text(
                  widget.demonstration
                      ? 'Você está usando uma conta de demonstração.'
                      : 'Conta autenticada com Google. As permissões são controladas pela equipe.',
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
