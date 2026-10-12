import 'dart:io';

// Fictional benchmark data only; never imported by the application entrypoint.
Future<void> writeBenchmarkOutput(String json) => File(
  '${Directory.systemTemp.path}/fiestaaa-navigation-benchmark.json',
).writeAsString(json).then((_) {});
