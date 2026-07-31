import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_nginx_config.dart' as nginx_config;

void main() {
  test('production accepts a public HTTPS API URL', () {
    final uri = nginx_config.validateApiBaseUrl(
      'https://api.fiestaaa.app',
      production: true,
    );

    expect(uri.host, 'api.fiestaaa.app');
  });

  test('production rejects a non-HTTPS API URL', () {
    expect(
      () => nginx_config.validateApiBaseUrl(
        'http://api.fiestaaa.app',
        production: true,
      ),
      throwsArgumentError,
    );
  });

  for (final host in ['localhost', 'service.localhost', '127.0.0.1', '::1']) {
    test('production rejects loopback host $host', () {
      final formattedHost = host.contains(':') ? '[$host]' : host;

      expect(
        () => nginx_config.validateApiBaseUrl(
          'https://$formattedHost:8080',
          production: true,
        ),
        throwsArgumentError,
      );
    });
  }

  test('development keeps supporting a local HTTP API', () {
    final uri = nginx_config.validateApiBaseUrl('http://localhost:8080');

    expect(uri.host, 'localhost');
    expect(uri.port, 8080);
  });
}
