import 'package:fiestaaa_front/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event route IDs accept positive integers only', () {
    expect(parseEventRouteId('42'), 42);
    expect(parseEventRouteId('0'), isNull);
    expect(parseEventRouteId('-1'), isNull);
    expect(parseEventRouteId('not-an-id'), isNull);
    expect(parseEventRouteId(null), isNull);
  });
}
