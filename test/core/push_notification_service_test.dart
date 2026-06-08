import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
