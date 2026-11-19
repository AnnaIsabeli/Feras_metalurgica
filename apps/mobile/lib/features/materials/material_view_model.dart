import 'package:flutter/foundation.dart';
import 'package:fera_contracts/fera_contracts.dart';

import 'material_repository.dart';

class MaterialViewModel extends ChangeNotifier {
  MaterialViewModel(this.repository, {required this.canManage})
    : status = canManage ? 'all' : 'active';
  final MaterialRepository repository;

  /// Permissão writeMaterials (administrador). Só controla a interface.
  final bool canManage;
  List<CatalogMaterial> items = [];
  bool loading = false;
  String? error;
  String query = '';
  String status;
  bool _disposed = false;

  Future<void> load({String? query, String? status}) async {
    if (_disposed) return;
    if (query != null) this.query = query.trim();
    if (status != null) this.status = status;
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await repository.list(query: this.query, status: this.status);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Cria (id nulo) ou edita. Devolve true se a API aceitou.
  Future<bool> save({
    String? id,
    required String name,
    required String unit,
    required String unitCost,
  }) => _run(
    () => id == null
        ? repository.create(name: name, unit: unit, unitCost: unitCost)
        : repository.update(id, name: name, unit: unit, unitCost: unitCost),
  );

  Future<bool> setActive(CatalogMaterial material, bool active) async {
    final ok = await _run(() => repository.update(material.id, active: active));
    if (ok) await load();
    return ok;
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (loading || _disposed) return false;
    loading = true;
    error = null;
    notifyListeners();
    var success = false;
    try {
      await action();
      success = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
