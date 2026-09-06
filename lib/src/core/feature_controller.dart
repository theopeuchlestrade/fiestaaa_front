import 'refresh_queue.dart';
import 'package:flutter/foundation.dart';

abstract class FeatureController extends ChangeNotifier {
  bool loading = false;
  Object? error;
  bool _disposed = false;
  final _refreshQueue = RefreshQueue();

  Future<void> refresh() => _refreshQueue.run('load', _runRefresh);

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
    _refreshQueue.dispose();
    super.dispose();
  }
}
