import 'package:fera_contracts/fera_contracts.dart';

import '../../core/api_client.dart';

abstract interface class QuoteRepository {
  Future<List<QuoteRequest>> list();
  Future<void> create({
    required String product,
    required String description,
    required int quantity,
  });
}

class ApiQuoteRepository implements QuoteRepository {
  ApiQuoteRepository(this.api);
  final ApiClient api;
  @override
  Future<List<QuoteRequest>> list() async {
    final json = await api.get('/v1/quote-requests');
    return (json['items'] as List)
        .map((item) => QuoteRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create({
    required String product,
    required String description,
    required int quantity,
  }) async {
    await api.post('/v1/quote-requests', {
      'product': product,
      'description': description,
      'quantity': quantity,
    });
  }
}
