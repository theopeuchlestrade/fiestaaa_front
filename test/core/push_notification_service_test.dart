import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
