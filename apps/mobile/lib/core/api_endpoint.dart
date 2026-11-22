import 'package:flutter/foundation.dart';

String apiBaseUrl({required bool authenticated}) {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (!authenticated) {
    return configured.isEmpty ? 'http://localhost:8080' : configured;
  }
  if (kIsWeb) return Uri.base.resolve('/api').toString();
  final uri = Uri.parse(
    configured.isEmpty ? 'https://orcex.shop/api' : configured,
  );
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw StateError('A API autenticada precisa usar HTTPS.');
  }
  return uri.toString();
}
