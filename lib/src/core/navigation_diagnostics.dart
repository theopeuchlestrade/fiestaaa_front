import 'dart:collection';

/// Opt-in, local-only timings. Labels are resource names, never URLs or payloads.
class NavigationDiagnostics {
  NavigationDiagnostics({this.enabled = false});
  static final instance = NavigationDiagnostics(
    enabled: const bool.fromEnvironment('NAVIGATION_DIAGNOSTICS'),
  );
  final bool enabled;
  final _samples = Queue<({String resource, int microseconds})>();
  List<({String resource, int microseconds})> get samples =>
      List.unmodifiable(_samples);
  void record(String resource, Duration duration) {
    if (!enabled) return;
    if (_samples.length == 1000) _samples.removeFirst();
    _samples.add((resource: resource, microseconds: duration.inMicroseconds));
  }

  Future<T> measure<T>(String resource, Future<T> Function() operation) async {
    if (!enabled) return operation();
    final watch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      record(resource, watch.elapsed);
    }
  }

  void clear() => _samples.clear();
}
