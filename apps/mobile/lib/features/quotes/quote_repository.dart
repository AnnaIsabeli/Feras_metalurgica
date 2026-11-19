import 'package:fera_contracts/fera_contracts.dart';

import '../../core/api_client.dart';

abstract interface class QuoteRepository {
  Future<List<QuoteRequest>> list({Map<String, String> filters = const {}});
  Future<void> create({
    required String product,
    required String description,
    required int quantity,
    String? customerName,
    String? customerContact,
  });
}

class ApiQuoteRepository implements QuoteRepository {
  ApiQuoteRepository(this.api);
  final ApiClient api;
  @override
  Future<List<QuoteRequest>> list({
    Map<String, String> filters = const {},
  }) async {
    final query = filters.isEmpty
        ? ''
        : '?${Uri(queryParameters: filters).query}';
    final json = await api.get('/v1/quote-requests$query');
    return (json['items'] as List)
        .map((item) => QuoteRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create({
    required String product,
    required String description,
    required int quantity,
    String? customerName,
    String? customerContact,
  }) async {
    await api.post('/v1/quote-requests', {
      'product': product,
      'description': description,
      'quantity': quantity,
      'customerName': ?customerName,
      'customerContact': ?customerContact,
    });
  }
}
