import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local payload preserves friendship and event destinations', () {
    for (final intent in [
      const PushNotificationIntent(type: 'friend_request', requestId: 4),
      const PushNotificationIntent(type: 'invite_received', eventId: 12),
    ]) {
      final restored = PushNotificationIntent.fromPayload(intent.toPayload())!;
      expect(restored.route, intent.route);
      expect(restored.requestId, intent.requestId);
      expect(restored.eventId, intent.eventId);
    }
  });

  test('invalid and old local payloads are ignored', () {
    for (final payload in [
      null,
      '',
      '{',
      '[]',
      '{"type":42}',
      '{"type":" "}',
    ]) {
      expect(PushNotificationIntent.fromPayload(payload), isNull);
    }
  });

  test('local notification tap emits the navigation intent', () async {
    final service = PushNotificationService.testing();
    final received = expectLater(
      service.intents,
      emits(
        isA<PushNotificationIntent>()
            .having((i) => i.route, 'route', '/friends')
            .having((i) => i.requestId, 'request ID', 4),
      ),
    );
    service.handleLocalNotificationResponse(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: const PushNotificationIntent(
          type: 'friend_request',
          requestId: 4,
        ).toPayload(),
      ),
    );
    await received;
    await service.dispose();
  });

  test('event notifications route to their event and reject invalid IDs', () {
    expect(
      const PushNotificationIntent(type: 'invite_received', eventId: 12).route,
      '/events/12',
    );
    expect(
      const PushNotificationIntent(type: 'invite_received', eventId: -1).route,
      isNull,
    );
    expect(const PushNotificationIntent(type: 'invite_received').route, isNull);
    expect(
      const PushNotificationIntent(type: 'friend_request', eventId: 12).route,
      '/friends',
    );
  });

  test(
    'init blocks push notifications when Firebase Messaging is unsupported',
    () async {
      final service = PushNotificationService.testing(
        messagingSupported: () async => false,
      );

      await service.init();
      await service.syncSession(
        SessionData(token: 'token-123', email: 'me@example.com'),
      );

      expect(service.isInitialized, isTrue);
      expect(service.isBlocked, isTrue);
    },
  );
}
