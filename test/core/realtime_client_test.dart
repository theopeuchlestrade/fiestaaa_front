import 'dart:math';

import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealtimeReconnectBackoff', () {
    test('backs off exponentially up to the reconnect cap', () {
      final backoff = RealtimeReconnectBackoff(jitterRatio: 0);

      expect(backoff.nextDelay(), const Duration(seconds: 2));
      expect(backoff.nextDelay(), const Duration(seconds: 4));
      expect(backoff.nextDelay(), const Duration(seconds: 8));
      expect(backoff.nextDelay(), const Duration(seconds: 16));
      expect(backoff.nextDelay(), const Duration(seconds: 30));
      expect(backoff.nextDelay(), const Duration(seconds: 30));
    });

    test('reset restarts the backoff window', () {
      final backoff = RealtimeReconnectBackoff(jitterRatio: 0);

      expect(backoff.nextDelay(), const Duration(seconds: 2));
      expect(backoff.nextDelay(), const Duration(seconds: 4));

      backoff.reset();

      expect(backoff.nextDelay(), const Duration(seconds: 2));
    });

    test('jitter stays within the configured delay bounds', () {
      final backoff = RealtimeReconnectBackoff(random: Random(1));

      final firstDelay = backoff.nextDelay();

      expect(
        firstDelay,
        greaterThanOrEqualTo(const Duration(milliseconds: 1600)),
      );
      expect(firstDelay, lessThanOrEqualTo(const Duration(milliseconds: 2400)));

      for (var i = 0; i < 10; i += 1) {
        expect(
          backoff.nextDelay(),
          lessThanOrEqualTo(const Duration(seconds: 30)),
        );
      }
    });
  });
}
