import 'package:fiestaaa_front/src/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildApiUri preserves the configured API origin and appends paths', () {
    final base = Uri.parse(apiBaseUrl);

    final uri = buildApiUri(
      '/events/42/items',
      queryParameters: {'scope': 'mine', 'sort': 'remaining'},
    );

    expect(uri.scheme, base.scheme);
    expect(uri.host, base.host);
    expect(uri.hasPort, base.hasPort);
    if (base.hasPort) {
      expect(uri.port, base.port);
    }
    expect(uri.pathSegments, [
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'events',
      '42',
      'items',
    ]);
    expect(uri.queryParameters, {'scope': 'mine', 'sort': 'remaining'});
  });

  test('buildWsUri converts HTTP API schemes to WebSocket schemes', () {
    final base = Uri.parse(apiBaseUrl);
    final expectedScheme = base.scheme == 'https' ? 'wss' : 'ws';

    final uri = buildWsUri('/ws', queryParameters: {'ticket': 'abc123'});

    expect(uri.scheme, expectedScheme);
    expect(uri.host, base.host);
    expect(uri.pathSegments.last, 'ws');
    expect(uri.queryParameters, {'ticket': 'abc123'});
  });
}
