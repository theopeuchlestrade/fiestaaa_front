import 'dart:convert';
import 'dart:io';

void main() {
  final team = Platform.environment['IOS_TEAM_ID'] ?? '';
  final fingerprints =
      (Platform.environment['ANDROID_APP_SIGNING_SHA256'] ?? '')
          .split(',')
          .map((s) => s.trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toList();
  if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(team) ||
      fingerprints.isEmpty ||
      fingerprints.any(
        (s) => !RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$').hasMatch(s),
      )) {
    throw ArgumentError(
      'Valid IOS_TEAM_ID and ANDROID_APP_SIGNING_SHA256 (Play app signing certificates) required',
    );
  }
  final directory = Directory('web/.well-known')..createSync(recursive: true);
  void write(String name, Object value) => File(
    '${directory.path}/$name',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');
  write('assetlinks.json', [
    {
      'relation': ['delegate_permission/common.handle_all_urls'],
      'target': {
        'namespace': 'android_app',
        'package_name': 'com.fiestaaa.fiestaaa',
        'sha256_cert_fingerprints': fingerprints,
      },
    },
  ]);
  write('apple-app-site-association', {
    'applinks': {
      'details': [
        {
          'appIDs': ['$team.com.fiestaaa.fiestaaa'],
          'components': [
            {'/': '/link'},
            {'/': '/reset-password'},
          ],
        },
      ],
    },
  });
}
