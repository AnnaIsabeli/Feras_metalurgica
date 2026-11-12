import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.code});
  final String message;

  /// Código HTTP devolvido pela API (ex.: 404). Nulo se nem chegou ao servidor.
  final int? status;

  /// Código do erro no corpo da resposta (ex.: pricing_not_found).
  final String? code;
  @override
  String toString() => message;
}

class QuotePdfDownload {
  const QuotePdfDownload(this.bytes, this.filename);
  final Uint8List bytes;
  final String filename;
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.token, http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final String token;
  final http.Client _client;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers.addAll({
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 10)),
      ).timeout(const Duration(seconds: 10));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        final error = json['error'] as Map?;
        throw ApiException(
          error?['message'] as String? ?? 'Serviço indisponível.',
          status: response.statusCode,
          code: error?['code'] as String?,
        );
      }
      return json;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar à API. Verifique a conexão e tente novamente.',
      );
    }
  }

  Future<QuotePdfDownload> getPdf(String path) async {
    try {
      final request = http.Request('GET', Uri.parse('$baseUrl$path'));
      request.headers['authorization'] = 'Bearer $token';
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) {
        Map? error;
        try {
          error = (jsonDecode(response.body) as Map)['error'] as Map?;
        } catch (_) {
          /* The gateway may return an HTML error instead of JSON. */
        }
        throw ApiException(
          error?['message'] as String? ?? 'Não foi possível obter o PDF.',
          status: response.statusCode,
          code: error?['code'] as String?,
        );
      }
      final bytes = response.bodyBytes;
      if ((response.headers['content-type'] ?? '')
                  .split(';')
                  .first
                  .toLowerCase() !=
              'application/pdf' ||
          bytes.length < 5 ||
          utf8.decode(bytes.take(5).toList(), allowMalformed: true) !=
              '%PDF-') {
        throw const ApiException('O servidor não devolveu um PDF válido.');
      }
      final header = response.headers['content-disposition'] ?? '';
      final name =
          RegExp(r'filename="([^"\r\n]+)"').firstMatch(header)?.group(1) ??
          'orcamento.pdf';
      final filename = name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      return QuotePdfDownload(bytes, filename);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível baixar o PDF. Verifique a conexão e tente novamente.',
      );
    }
  }

  void close() => _client.close();
}
