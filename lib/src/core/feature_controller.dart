import 'package:flutter/foundation.dart';

abstract class FeatureController extends ChangeNotifier {
  bool loading = false;
  Object? error;
  bool _disposed = false;
  Future<void>? _refresh;

  Future<void> refresh() => _refresh ??= _runRefresh();

  Future<void> _runRefresh() async {
    loading = true;
    error = null;
    notifySafely();
    try {
      await load();
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      _refresh = null;
      notifySafely();
    }
  }

  @protected
  Future<void> load();

  @protected
  void notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
