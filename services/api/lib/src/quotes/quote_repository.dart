import 'package:fera_contracts/fera_contracts.dart';

abstract interface class QuoteRepository {
  Future<List<QuoteRequest>> list({
    String? buyerId,
    String? customer,
    String? from,
    String? to,
    String? status,
  });
  Future<QuoteRequest> create(QuoteRequest request);
  Future<QuoteRequest?> find(String id);
  Future<QuoteRequest?> transition({
    required String id,
    required String expected,
    required String target,
    required String actorId,
  });
}
