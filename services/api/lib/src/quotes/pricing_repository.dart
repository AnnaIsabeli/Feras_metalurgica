abstract interface class PricingRepository {
  Future<List<Map<String, dynamic>>> materials();
  Future<Map<String, dynamic>?> material(String id);
  Future<Map<String, dynamic>?> save({
    required String requestId,
    required String actorId,
    required Map<String, dynamic> input,
    required Map<String, dynamic> result,
    required int totalPriceCents,
  });
  Future<Map<String, dynamic>?> latest(String requestId);
}
