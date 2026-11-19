import 'package:flutter/foundation.dart';
import 'package:fera_contracts/fera_contracts.dart';

import 'quote_repository.dart';

class QuoteViewModel extends ChangeNotifier {
  QuoteViewModel(this.repository);
  final QuoteRepository repository;
  List<QuoteRequest> items = [];
  bool loading = false;
  String? error;
  bool _disposed = false;

  Map<String, String> _filters = const {};
  Future<void> load({Map<String, String>? filters}) async {
    if (loading || _disposed) return;
    if (filters != null) _filters = Map.unmodifiable(filters);
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await repository.list(filters: _filters);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> submit(
    String product,
    String description,
    int quantity, {
    String? customerName,
    String? customerContact,
  }) async {
    if (loading || _disposed) return false;
    loading = true;
    error = null;
    notifyListeners();
    var success = false;
    try {
      await repository.create(
        product: product,
        description: description,
        quantity: quantity,
        customerName: customerName,
        customerContact: customerContact,
      );
      success = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
    // List reload is separate: a failed refresh must not invite duplicate POSTs.
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
