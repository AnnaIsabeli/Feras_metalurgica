import 'package:fera_contracts/fera_contracts.dart';

abstract interface class QuoteRepository {
  Future<List<QuoteRequest>> list({String? buyerId});
  Future<QuoteRequest> create(QuoteRequest request);
}
