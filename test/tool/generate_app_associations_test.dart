import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('tool/generate_app_associations.dart').absolute.path;
  late Directory root;
  setUp(
    () => root = Directory.systemTemp.createTempSync('fiestaaa-associations-'),
  );
  tearDown(() => root.deleteSync(recursive: true));

  Future<ProcessResult> generate({
    String mode = 'all',
    String fingerprint = '',
    String team = '7SYCW3N9JB',
  }) => Process.run(
    'dart',
    [script],
    workingDirectory: root.path,
    environment: {
      'FIESTAAA_APP_ASSOCIATION_PLATFORMS': mode,
      'IOS_TEAM_ID': team,
      'ANDROID_APP_SIGNING_SHA256': fingerprint,
    },
  );

  test(
    'iOS-only mode writes valid AASA and removes stale Android association',
    () async {
      final android = File('${root.path}/web/.well-known/assetlinks.json');
      android.parent.createSync(recursive: true);
      android.writeAsStringSync('stale');
      final result = await generate(mode: 'ios');
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final aasa = jsonDecode(
        File(
          '${android.parent.path}/apple-app-site-association',
        ).readAsStringSync(),
      );
      expect(aasa['applinks']['details'][0]['appIDs'], [
        '7SYCW3N9JB.com.fiestaaa.fiestaaa',
      ]);
      expect(aasa['applinks']['details'][0]['components'], [
        {'/': '/link'},
        {'/': '/reset-password'},
      ]);
      expect(android.existsSync(), isFalse);
    },
  );

  test(
    'all-platform mode refuses missing or malformed Play certificates',
    () async {
      for (final fingerprint in ['', 'not-a-certificate']) {
        expect((await generate(fingerprint: fingerprint)).exitCode, isNot(0));
        expect(Directory('${root.path}/web').existsSync(), isFalse);
      }
    },
  );

  test('all-platform mode includes supplied Play certificate', () async {
    final fingerprint = List.filled(32, 'AB').join(':');
    final result = await generate(fingerprint: fingerprint);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final entries = jsonDecode(
      File('${root.path}/web/.well-known/assetlinks.json').readAsStringSync(),
    );
    expect(entries[0]['target']['sha256_cert_fingerprints'], [fingerprint]);
    expect(
      File(
        '${root.path}/web/.well-known/apple-app-site-association',
      ).existsSync(),
      isTrue,
    );
  });

  test('invalid mode or Apple team fails before writing files', () async {
    expect((await generate(mode: 'none')).exitCode, isNot(0));
    expect((await generate(mode: 'ios', team: 'invalid')).exitCode, isNot(0));
    expect(Directory('${root.path}/web').existsSync(), isFalse);
  });
}
