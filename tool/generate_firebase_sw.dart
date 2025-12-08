import 'dart:io';

/// Generate web/firebase-messaging-sw.js from .env and the template.
Future<void> main() async {
  final envFile = File('.env');
  if (!await envFile.exists()) {
    stderr.writeln('Missing .env file at project root.');
    exitCode = 1;
    return;
  }

  final env = _parseEnv(await envFile.readAsLines());
  final requiredKeys = <String>[
    'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_WEB_API_KEY',
    'FIREBASE_WEB_APP_ID',
  ];

  final missing = requiredKeys.where((k) => (env[k] ?? '').isEmpty).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing required env keys: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }

  // Compute auth domain from project id if not provided.
  env.putIfAbsent(
    'FIREBASE_AUTH_DOMAIN',
    () => '${env['FIREBASE_PROJECT_ID']}.firebaseapp.com',
  );
  env.putIfAbsent('FIREBASE_WEB_MEASUREMENT_ID', () => '');

  final templatePath = 'web/firebase-messaging-sw.template.js';
  final templateFile = File(templatePath);
  if (!await templateFile.exists()) {
    stderr.writeln('Template not found at $templatePath');
    exitCode = 1;
    return;
  }

  var content = await templateFile.readAsString();
  for (final entry in env.entries) {
    content = content.replaceAll('{{${entry.key}}}', entry.value);
  }

  final outputPath = 'web/firebase-messaging-sw.js';
  await File(outputPath).writeAsString(content);
  stdout.writeln('Generated $outputPath from $templatePath and .env');
}

Map<String, String> _parseEnv(List<String> lines) {
  final map = <String, String>{};
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    map[key] = value;
  }
  return map;
}
