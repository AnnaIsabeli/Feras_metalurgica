import 'dart:convert';
import 'package:fera_mobile/core/api_client.dart';
import 'package:fera_mobile/features/admin/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeAdminServer {
  final invitations = <Map<String, dynamic>>[];
  Future<http.Response> handle(http.Request request) async {
    expect(request.headers['authorization'], 'Bearer owner-google');
    Object result = {};
    if (request.url.path == '/v1/admin/session') {
      expect(jsonDecode(request.body), {'code': '123456'});
      result = {'session': List.filled(43, 'a').join(), 'expiresIn': 300};
    } else {
      expect(request.headers['x-admin-session'], List.filled(43, 'a').join());
      if (request.url.path == '/v1/admin/overview') {
        result = {'users': [], 'invitations': [], 'audit': []};
      }
      if (request.url.path == '/v1/admin/invitations') {
        invitations.add(jsonDecode(request.body) as Map<String, dynamic>);
        result = {'status': 'pending'};
      }
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<void> open(WidgetTester tester, FakeAdminServer server) async {
  await tester.binding.setSurfaceSize(const Size(1100, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiClient(
    baseUrl: 'http://localhost',
    token: 'owner-google',
    client: MockClient(server.handle),
  );
  addTearDown(api.close);
  await tester.pumpWidget(MaterialApp(home: AdminScreen(api: api)));
  await tester.pumpAndSettle();
}

Future<void> unlock(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Código do autenticador'),
    '123456',
  );
  await tester.tap(find.text('Desbloquear administração'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'permissions cannot be submitted before MFA or before confirmation',
    (tester) async {
      final server = FakeAdminServer();
      await open(tester, server);
      expect(find.text('Revisar autorização'), findsNothing);
      await unlock(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail da conta Google'),
        'teammate@example.invalid',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo da autorização'),
        'Acesso da equipe autorizado',
      );
      await tester.ensureVisible(find.text('Revisar autorização'));
      await tester.tap(find.text('Revisar autorização'));
      await tester.pumpAndSettle();
      expect(server.invitations, isEmpty);
      expect(find.textContaining('teammate@example.invalid'), findsWidgets);
      await tester.tap(find.text('Confirmar autorização'));
      await tester.pumpAndSettle();
      expect(server.invitations.single['email'], 'teammate@example.invalid');
      expect(server.invitations.single['role'], 'seller');
      expect(server.invitations.single['commandId'], isNotEmpty);
    },
  );
  testWidgets('expiring the administrative session hides access management', (
    tester,
  ) async {
    final server = FakeAdminServer();
    await open(tester, server);
    await unlock(tester);
    expect(find.text('Gerenciar acessos'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(find.text('Gerenciar acessos'), findsNothing);
    expect(find.text('Confirme seu acesso'), findsOneWidget);
    expect(find.text('Revisar autorização'), findsNothing);
  });
}
