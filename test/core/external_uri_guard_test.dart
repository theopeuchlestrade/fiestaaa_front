import 'package:fiestaaa_front/src/core/external_uri_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts absolute http and https URIs', () {
    expect(tryParseSafeAbsoluteHttpUri('https://fiestaaa.app/pay'), isNotNull);
    expect(
      tryParseSafeAbsoluteHttpUri('http://localhost:8080/mock-pay'),
      isNotNull,
    );
  });

  test('rejects dangerous or malformed schemes', () {
    expect(tryParseSafeAbsoluteHttpUri('javascript:alert(1)'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('data:text/html,boom'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('spotify:playlist:123'), isNull);
    expect(tryParseSafeAbsoluteHttpUri('/relative/path'), isNull);
  });
}
