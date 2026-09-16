import 'package:fera_contracts/fera_contracts.dart';
import 'package:fera_mobile/features/quotes/quote_repository.dart';
import 'package:fera_mobile/features/quotes/quote_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeQuotes implements QuoteRepository {
  bool failLoad = false;
  bool failCreate = false;
  int creates = 0;
  @override
  Future<List<QuoteRequest>> list() async {
    if (failLoad) throw Exception('Sem conexão');
    return [];
  }

  @override
  Future<void> create({
    required String product,
    required String description,
    required int quantity,
  }) async {
    if (failCreate) throw Exception('Falha ao enviar');
    creates++;
  }
}

void main() {
  test('load exposes recoverable failure and clears it on retry', () async {
    final repository = FakeQuotes()..failLoad = true;
    final model = QuoteViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    expect(model.error, contains('Sem conexão'));
    expect(model.loading, isFalse);
    repository.failLoad = false;
    await model.load();
    expect(model.error, isNull);
  });
  test(
    'successful creation stays successful even if next refresh fails',
    () async {
      final repository = FakeQuotes()..failLoad = true;
      final model = QuoteViewModel(repository);
      addTearDown(model.dispose);
      expect(await model.submit('Portão', '3 metros', 1), isTrue);
      await model.load();
      expect(repository.creates, 1);
      expect(model.error, isNotNull);
    },
  );
}
