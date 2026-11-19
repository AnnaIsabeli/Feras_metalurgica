import 'dart:convert';
import '../documents/quote_pdf_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../auth/principal.dart';
import '../core/api_error.dart';
import '../quotes/quote_service.dart';
import 'pricing_endpoint.dart';
import '../quotes/pricing_service.dart';

Response jsonResponse(int status, Object body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Handler buildHandler({
  required QuoteService quotes,
  PricingService? pricings,
  QuotePdfService? pdfs,
  required IdentityVerifier identity,
  required Future<void> Function() checkDatabase,
  required String allowedOrigin,
}) {
  Future<Principal> actor(Request request) async {
    final header = request.headers['authorization'];
    final principal = header != null && header.startsWith('Bearer ')
        ? await identity.verify(header.substring(7))
        : null;
    if (principal == null) {
      throw const ApiError(401, 'unauthorized', 'Autenticação necessária.');
    }
    return principal;
  }

  Future<Map<String, dynamic>> readJson(Request request) async {
    if (!(request.headers['content-type'] ?? '').toLowerCase().startsWith(
      'application/json',
    )) {
      throw const ApiError(
        415,
        'unsupported_media_type',
        'Envie application/json.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      if (bytes.length + chunk.length > 16384) {
        throw const ApiError(
          413,
          'payload_too_large',
          'Solicitação muito grande.',
        );
      }
      bytes.addAll(chunk);
    }
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const ApiError(400, 'invalid_json', 'JSON inválido.');
    }
    if (data is! Map<String, dynamic>) {
      throw const ApiError(400, 'invalid_json', 'Envie um objeto JSON.');
    }
    return data;
  }

  final router = Router()
    ..get('/health', (Request _) => jsonResponse(200, {'status': 'ok'}))
    ..get('/ready', (Request _) async {
      try {
        await checkDatabase();
        return jsonResponse(200, {'status': 'ready'});
      } catch (_) {
        return jsonResponse(503, {'status': 'unavailable'});
      }
    })
    ..get('/v1/me', (Request request) async {
      final user = await actor(request);
      return jsonResponse(200, {
        'id': user.id,
        'role': user.role.name,
        'sellerApproved': user.sellerApproved,
      });
    })
    ..get('/v1/quote-requests', (Request request) async {
      final items = await quotes.list(await actor(request));
      return jsonResponse(200, {
        'items': items.map((q) => q.toJson()).toList(),
      });
    })
    ..post('/v1/pricing/calculate', (Request request) async {
      final user = await actor(request);
      if (user.role != UserRole.seller || !user.sellerApproved) {
        throw const ApiError(
          403,
          'seller_required',
          'Somente vendedores aprovados podem calcular preços.',
        );
      }
      return jsonResponse(200, calculatePricing(await readJson(request)));
    })
    ..post('/v1/quote-requests', (Request request) async {
      final user = await actor(request);
      final data = await readJson(request);
      return jsonResponse(201, (await quotes.create(user, data)).toJson());
    });

  if (pricings != null) {
    router.get(
      '/v1/materials',
      (Request request) async => jsonResponse(200, {
        'items': await pricings.materials(await actor(request)),
      }),
    );
    router.get(
      '/v1/quote-requests/<id>/pricing',
      (Request request, String id) async =>
          jsonResponse(200, await pricings.latest(await actor(request), id)),
    );
    router.post('/v1/quote-requests/<id>/pricing', (
      Request request,
      String id,
    ) async {
      final user = await actor(request);
      pricings.authorize(user);
      return jsonResponse(
        201,
        await pricings.save(user, id, await readJson(request)),
      );
    });
  }

  if (pdfs != null) {
    router.get('/v1/quote-requests/<id>/pdf', (
      Request request,
      String id,
    ) async {
      final user = await actor(request);
      pdfs.authorize(user);
      final download = request.url.queryParameters['download'];
      if (download != null && download != '0' && download != '1') {
        throw const ApiError(
          422,
          'invalid_download',
          'Use download=1 para baixar o arquivo.',
        );
      }
      final file = await pdfs.generate(
        user,
        id,
        pricingId: request.url.queryParameters['pricingId'],
      );
      return Response.ok(
        file.bytes,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition':
              '${download == '1' ? 'attachment' : 'inline'}; filename="${file.filename}"',
          'content-length': file.bytes.length.toString(),
          'cache-control': 'private, no-store',
          'pragma': 'no-cache',
          'x-content-type-options': 'nosniff',
        },
      );
    });
  }

  final allowedOrigins = allowedOrigin
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  return (request) async {
    final origin = request.headers['origin'];
    if (origin != null && !allowedOrigins.contains(origin)) {
      return jsonResponse(403, {
        'error': {'code': 'origin_denied', 'message': 'Origem não permitida.'},
      });
    }
    final cors = <String, String>{
      'access-control-allow-origin': ?origin,
      'vary': 'Origin',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
      'access-control-allow-headers': 'Authorization, Content-Type',
      'access-control-expose-headers': 'Content-Disposition',
    };
    Response response;
    try {
      response = request.method == 'OPTIONS'
          ? Response(204)
          : await router.call(request);
    } on ApiError catch (e) {
      response = jsonResponse(e.status, {
        'error': {'code': e.code, 'message': e.message},
      });
    } catch (_) {
      // Avoid exposing SQL details, connection strings or tokens in responses.
      response = jsonResponse(500, {
        'error': {
          'code': 'internal_error',
          'message': 'Não foi possível concluir a operação.',
        },
      });
    }
    return response.change(headers: cors);
  };
}
