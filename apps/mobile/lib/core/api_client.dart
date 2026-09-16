import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
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
        throw ApiException(
          (json['error'] as Map?)?['message'] as String? ??
              'Serviço indisponível.',
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

  void close() => _client.close();
}
