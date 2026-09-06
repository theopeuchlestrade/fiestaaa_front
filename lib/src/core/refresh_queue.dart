import 'dart:async';

/// Serializes each resource's reads and retains an invalidation received in flight.
class RefreshQueue {
  final _pending = <Object, Future<void> Function()>{};
  final _running = <Object, Completer<void>>{};
  bool _disposed = false;

  Future<void> run(Object key, Future<void> Function() load) {
    if (_disposed) return Future.value();
    _pending[key] = load;
    final running = _running[key];
    if (running != null) return running.future;
    final completer = Completer<void>();
    _running[key] = completer;
    unawaited(_drain(key, completer));
    return completer.future;
  }

  Future<void> _drain(Object key, Completer<void> completer) async {
    Object? failure;
    StackTrace? stack;
    while (!_disposed && _pending.containsKey(key)) {
      final load = _pending.remove(key)!;
      try {
        await load();
        failure = null;
      } catch (error, trace) {
        failure = error;
        stack = trace;
      }
    }
    _running.remove(key);
    if (failure != null && !_disposed) {
      completer.completeError(failure, stack);
    } else {
      completer.complete();
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
  }
}
