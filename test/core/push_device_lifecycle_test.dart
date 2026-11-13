import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Messaging
    with MockPlatformInterfaceMixin
    implements FirebaseMessagingPlatform {
  final refreshed = StreamController<String>.broadcast();
  String? token = 'device-one';
  String? apns = 'apns-fixture';
  bool denied = false;
  RemoteMessage? initial;
  int tokenReads = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #delegateFor:
      case #setInitialValues:
        return this;
      case #onTokenRefresh:
        return refreshed.stream;
      case #getToken:
        tokenReads++;
        return Future<String?>.value(token);
      case #getAPNSToken:
        return Future<String?>.value(apns);
      case #getInitialMessage:
        return Future<RemoteMessage?>.value(initial);
      case #requestPermission:
        return Future<NotificationSettings>.value(
          NotificationSettings(
            authorizationStatus: denied
                ? AuthorizationStatus.denied
                : AuthorizationStatus.authorized,
            alert: AppleNotificationSetting.enabled,
            announcement: AppleNotificationSetting.disabled,
            badge: AppleNotificationSetting.enabled,
            carPlay: AppleNotificationSetting.disabled,
            criticalAlert: AppleNotificationSetting.disabled,
            lockScreen: AppleNotificationSetting.enabled,
            notificationCenter: AppleNotificationSetting.enabled,
            showPreviews: AppleShowPreviewSetting.always,
            sound: AppleNotificationSetting.enabled,
            timeSensitive: AppleNotificationSetting.disabled,
            providesAppNotificationSettings: AppleNotificationSetting.disabled,
          ),
        );
      case #setAutoInitEnabled:
      case #setForegroundNotificationPresentationOptions:
        return Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channelCalls = <MethodCall>[];
  final messaging = _Messaging();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseMessagingPlatform.instance = messaging;
    PackageInfo.setMockInitialValues(
      appName: 'QA',
      packageName: 'fixture',
      version: '0.7.0',
      buildNumber: '9000',
      buildSignature: 'fixture',
    );
  });
  setUp(() {
    channelCalls.clear();
    messaging.token = "device-one";
    messaging.apns = "apns-fixture";
    messaging.denied = false;
    messaging.tokenReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            channelCalls.add(call);
            if (call.method == 'getNotificationAppLaunchDetails') {
              return {'notificationLaunchedApp': false};
            }
            return true;
          },
        );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'device registration, rotation and logout use $platform metadata once',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        if (platform == TargetPlatform.android) {
          AndroidFlutterLocalNotificationsPlugin.registerWith();
        } else {
          IOSFlutterLocalNotificationsPlugin.registerWith();
        }
        final requests = <http.Request>[];
        await runZoned(
          () async {
            final service = PushNotificationService.testing(
              messagingSupported: () async => true,
            );
            await service.init();
            service.setLocaleTag(' en-GB ');
            await service.syncSession(
              SessionData(
                token: 'account-fixture',
                email: 'guest@example.invalid',
              ),
            );
            expect(service.isBlocked, isFalse);
            expect(requests, hasLength(1));
            expect(jsonDecode(requests.first.body), {
              'token': 'device-one',
              'platform': platform == TargetPlatform.iOS ? 'ios' : 'android',
              'locale': 'en-GB',
              'app_version': '0.7.0+9000',
            });
            await service.syncSession(
              SessionData(
                token: 'account-fixture',
                email: 'guest@example.invalid',
              ),
            );
            expect(requests, hasLength(1));
            messaging.refreshed.add('device-two');
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await Future<void>.delayed(const Duration(milliseconds: 20));
            expect(requests, hasLength(2));
            expect(requests.last.url.path, endsWith('/me/devices/refresh'));
            expect(jsonDecode(requests.last.body)['old_token'], 'device-one');
            await service.clearSession();
            expect(requests.last.url.path, endsWith('/me/devices/revoke'));
            expect(jsonDecode(requests.last.body), {'token': 'device-two'});
            await service.dispose();
            debugDefaultTargetPlatformOverride = null;
          },
          zoneValues: {
            apiHttpClientFactoryKey: () => MockClient((request) async {
              requests.add(request);
              return http.Response('{}', 204);
            }),
          },
        );
      },
    );
  }
  test('denied permission never registers a device', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messaging.denied = true;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    var requests = 0;
    await runZoned(
      () async {
        final service = PushNotificationService.testing(
          messagingSupported: () async => true,
        );
        await service.init();
        await service.syncSession(
          SessionData(token: 'fixture', email: 'guest@example.invalid'),
        );
        expect(service.isBlocked, isTrue);
        expect(requests, 0);
        await service.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      },
    );
  });
  test(
    'missing APNs token retries registration after it becomes available',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messaging.apns = null;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      var requests = 0;
      await runZoned(
        () async {
          final service = PushNotificationService.testing(
            messagingSupported: () async => true,
          );
          await service.init();
          await service.syncSession(
            SessionData(token: 'fixture', email: 'guest@example.invalid'),
          );
          expect(requests, 0);
          expect(messaging.tokenReads, 0);
          messaging.apns = 'apns-fixture';
          await Future<void>.delayed(const Duration(milliseconds: 2100));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(requests, 1);
          await service.clearSession();
          await service.dispose();
          debugDefaultTargetPlatformOverride = null;
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        },
      );
    },
  );
}
