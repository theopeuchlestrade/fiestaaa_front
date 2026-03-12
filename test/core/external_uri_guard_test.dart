import 'package:fiestaaa_front/src/core/external_uri_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts absolute http and https URIs', () {
    expect(tryParseSafeAbsoluteHttpUri('https://fiestaaa.app/pay'), isNotNull);
    expect(
      tryParseSafeAbsoluteHttpUri('https://[2001:4860:4860::8888]/pay'),
      isNotNull,
    );
  });

  test('rejects dangerous or malformed schemes', () {
    expect(tryParseSafeAbsoluteHttpUri('javascript:alert(1)'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('data:text/html,boom'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('spotify:playlist:123'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('/relative/path'), isNull);
  });

  test('rejects localhost and private network targets', () {
    expect(
      tryParseSafeAbsoluteHttpUri('http://localhost:8080/mock-pay'),
      isNull,
    );
    expect(tryParseSafeAbsoluteHttpUri('http://localhost./mock-pay'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('https://foo.localhost/pay'), isNull);
    expect(
      tryParseSafeAbsoluteHttpUri('http://127.0.0.1:8080/mock-pay'),
      isNull,
    );
    expect(tryParseSafeAbsoluteHttpUri('https://10.0.0.42/pay'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('https://192.168.1.5/pay'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('https://[::1]/pay'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('https://[fe80::1]/pay'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('https://[fc00::1]/pay'), isNull);
    expect(
      tryParseSafeAbsoluteHttpUri('https://[::ffff:127.0.0.1]/pay'),
      isNull,
    );
  });
}
