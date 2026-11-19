import 'dart:convert';

import 'package:fera_mobile/app.dart';
import 'package:fera_mobile/core/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A API simulada devolve o que `/v1/me` devolveria para cada perfil.
/// O teste prova que a interface só mostra o que as permissões permitem.
ApiClient fakeApi({
  required String role,
  bool approved = false,
  required List<String> permissions,
  List<String>? requested,
}) => ApiClient(
  baseUrl: 'http://fake',
  token: 'x',
  client: MockClient((request) async {
    requested?.add('${request.method} ${request.url.path}');
    final body = request.url.path == '/v1/me'
        ? {
            'id': '1',
            'role': role,
            'sellerApproved': approved,
            'permissions': permissions,
          }
        : {'items': <Object>[]};
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Future<void> open(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(MaterialApp(home: AppShell(token: 'x', api: api)));
  await tester.pumpAndSettle();
}

void main() {
  const buyerPermissions = ['createQuote', 'listQuotes', 'readQuote', 'downloadQuotePdf'];
  const sellerPermissions = [
    'listQuotes',
    'readQuote',
    'downloadQuotePdf',
    'readMaterials',
  ];
  const adminPermissions = [
    'listQuotes',
    'readQuote',
    'downloadQuotePdf',
    'readMaterials',
    'readInactiveMaterials',
    'writeMaterials',
  ];

  testWidgets('cliente vê Orçamentos e Contato, e não vê catálogo', (tester) async {
    await open(tester, fakeApi(role: 'buyer', permissions: buyerPermissions));
    expect(find.text('Orçamentos'), findsOneWidget);
    expect(find.text('Contato'), findsOneWidget);
    expect(find.text('Catálogo'), findsNothing);
    expect(find.text('Materiais'), findsNothing);
    expect(find.text('Olá, Cliente'), findsOneWidget);
  });

  testWidgets('vendedor aprovado consulta materiais sem botões de edição', (tester) async {
    final calls = <String>[];
    await open(
      tester,
      fakeApi(role: 'seller', approved: true, permissions: sellerPermissions, requested: calls),
    );
    expect(find.text('Materiais'), findsOneWidget);
    expect(find.text('Catálogo'), findsNothing);
    await tester.tap(find.text('Materiais'));
    await tester.pumpAndSettle();
    expect(find.text('Materiais ativos'), findsOneWidget);
    expect(find.text('Cadastrar material'), findsNothing);
    expect(find.text('Todos'), findsNothing);
  });

  testWidgets('administrador vê o catálogo com cadastro e filtros', (tester) async {
    await open(tester, fakeApi(role: 'admin', permissions: adminPermissions));
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Contato'), findsNothing);
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar material'), findsOneWidget);
    expect(find.text('Inativos'), findsOneWidget);
  });

  testWidgets('vendedor não aprovado não vê abas de trabalho', (tester) async {
    await open(tester, fakeApi(role: 'seller', approved: false, permissions: const []));
    expect(find.textContaining('ainda não foi aprovado'), findsOneWidget);
    expect(find.text('Orçamentos'), findsNothing);
    expect(find.text('Materiais'), findsNothing);
    expect(find.text('Abrir orçamentos'), findsNothing);
  });

  testWidgets('sem sessão válida mostra erro e permite tentar de novo', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://fake',
      token: 'x',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': {'code': 'unauthorized', 'message': 'Autenticação necessária.'}}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await open(tester, api);
    expect(find.text('Autenticação necessária.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Orçamentos'), findsNothing);
  });
}
