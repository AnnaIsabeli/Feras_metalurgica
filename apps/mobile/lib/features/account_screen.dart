import 'package:flutter/material.dart';

import '../core/api_client.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.api});
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
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
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
                const Icon(Icons.account_circle_outlined, size: 72),
                const SizedBox(height: 16),
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
                const Text(
                  'Você está usando uma conta de demonstração. O login com Google ainda não está disponível.',
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
