import 'dart:async';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/notifications/data/notifications_api.dart';
import 'config.dart';
import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_html.dart' as web_notif;

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationsApi _api = NotificationsApi();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _cachedToken;
  String? _registeredToken;
  SessionData? _session;
  StreamSubscription<String>? _tokenStreamSub;
  bool _blocked = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _requestPermissions();
    await _initLocalNotifications();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    _cachedToken = await _safeGetToken();
    _tokenStreamSub = _messaging.onTokenRefresh.listen((token) async {
      final previous = _cachedToken;
      _cachedToken = token;
      if (_session != null) {
        try {
          await _api.refreshDevice(
            authToken: _session!.token,
            oldToken: previous ?? token,
            newToken: token,
            platform: _platform(),
            locale: _locale(),
            appVersion: _appVersion(),
          );
          _registeredToken = token;
        } catch (_) {}
      }
    });
  }

  Future<void> syncSession(SessionData session) async {
    _session = session;
    if (!_initialized) {
      await init();
    }
    if (_blocked) return;
    final token = _cachedToken ?? await _safeGetToken();
    if (token == null) return;

    if (_registeredToken == token) return;

    try {
      if (_registeredToken != null) {
        await _api.refreshDevice(
          authToken: session.token,
          oldToken: _registeredToken!,
          newToken: token,
          platform: _platform(),
          locale: _locale(),
          appVersion: _appVersion(),
        );
      } else {
        await _api.registerDevice(
          authToken: session.token,
          fcmToken: token,
          platform: _platform(),
          locale: _locale(),
          appVersion: _appVersion(),
        );
      }
      _registeredToken = token;
      _cachedToken = token;
    } catch (_) {
      // Ignore network/API errors here; token will be retried on next refresh/login.
    }
  }

  Future<void> clearSession() async {
    if (_session != null && _registeredToken != null) {
      try {
        await _api.deleteDevice(
          authToken: _session!.token,
          fcmToken: _registeredToken!,
        );
      } catch (_) {}
    }
    _session = null;
    _registeredToken = null;
  }

  Future<void> dispose() async {
    await _tokenStreamSub?.cancel();
  }

  Future<void> _requestPermissions() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (_) {
      // Permission request failed (blocked); continue without notifications.
      _blocked = true;
    }
  }

  Future<String?> _safeGetToken() async {
    try {
      return await _messaging.getToken(
        vapidKey: kIsWeb && fcmWebVapidKey.isNotEmpty ? fcmWebVapidKey : null,
      );
    } catch (_) {
      _blocked = true;
      return null;
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }

  String? _locale() {
    final loc = PlatformDispatcher.instance.locale;
    final code = loc.toLanguageTag();
    return code.isEmpty ? null : code;
  }

  String? _appVersion() {
    // Could be wired later from package_info_plus; keep nullable for now.
    return null;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    if (kIsWeb) {
      await web_notif.showWebNotification(
        notif.title ?? 'Notification',
        notif.body ?? '',
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'fiestaaa_fcm',
      'Notifications',
      channelDescription: 'Notifications Fiestaaa en foreground',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _localNotifications.show(
      notif.hashCode,
      notif.title,
      notif.body,
      details,
    );
  }
}
