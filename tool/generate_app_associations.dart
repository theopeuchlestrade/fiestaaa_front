import 'dart:convert';
import 'dart:io';

void main() {
  final platforms =
      Platform.environment['FIESTAAA_APP_ASSOCIATION_PLATFORMS'] ?? 'all';
  if (platforms != 'all' && platforms != 'ios') {
    throw ArgumentError('App association platforms must be all or ios');
  }
  final includeAndroid = platforms == 'all';
  final team = Platform.environment['IOS_TEAM_ID'] ?? '';
  final fingerprints =
      (Platform.environment['ANDROID_APP_SIGNING_SHA256'] ?? '')
          .split(',')
          .map((s) => s.trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toList();
  if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(team) ||
      (includeAndroid &&
          (fingerprints.isEmpty ||
              fingerprints.any(
                (s) => !RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$').hasMatch(s),
              )))) {
    throw ArgumentError(
      'Valid IOS_TEAM_ID required; all-platform builds also require ANDROID_APP_SIGNING_SHA256 (Play app signing certificates)',
    );
  }
  final directory = Directory('web/.well-known')..createSync(recursive: true);
  void write(String name, Object value) => File(
    '${directory.path}/$name',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');
  if (includeAndroid) {
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
  } else {
    final androidFile = File('${directory.path}/assetlinks.json');
    if (androidFile.existsSync()) androidFile.deleteSync();
  }
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
