import 'package:flutter/material.dart';

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
                    initialValue: widget.profile!.name,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: widget.profile!.email,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 24),
                ],
                ListTile(
                  title: const Text('Tipo de acesso'),
                  subtitle: Text(
                    snapshot.data!['role'] == 'seller'
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
