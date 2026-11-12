import 'dart:convert';
import 'package:fera_mobile/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'fetches authenticated PDF bytes and filename without placing token in URL',
    () async {
      final client = ApiClient(
        baseUrl: 'https://dev.example.com/api',
        token: 'secret-demo-token',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer secret-demo-token');
          expect(request.url.toString(), isNot(contains('secret-demo-token')));
          expect(request.url.queryParameters['pricingId'], 'revision');
          return http.Response.bytes(
            utf8.encode('%PDF-1.7\nexample'),
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition':
                  'attachment; filename="orcamento-teste.pdf"',
            },
          );
        }),
      );
      addTearDown(client.close);
      final file = await client.getPdf(
        '/v1/quote-requests/id/pdf?pricingId=revision&download=1',
      );
      expect(file.filename, 'orcamento-teste.pdf');
      expect(utf8.decode(file.bytes), startsWith('%PDF-'));
    },
  );
  test(
    'preserves API authorization errors and rejects HTML pretending to be PDF',
    () async {
      var forbidden = true;
      final client = ApiClient(
        baseUrl: 'https://dev.example.com/api',
        token: 'demo',
        client: MockClient(
          (_) async => forbidden
              ? http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'seller_required',
                      'message': 'Acesso negado.',
                    },
                  }),
                  403,
                )
              : http.Response(
                  '<html>error</html>',
                  200,
                  headers: {'content-type': 'application/pdf'},
                ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.getPdf('/pdf'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      forbidden = false;
      await expectLater(
        client.getPdf('/pdf'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('PDF válido'),
          ),
        ),
      );
    },
  );
}
