import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/notifications/data/notifications_api.dart';
import 'config.dart';
import 'firebase_messaging_support.dart';
import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_html.dart'
    as web_notif;

typedef FirebaseMessagingSupportChecker = Future<bool> Function();

class PushNotificationIntent {
  const PushNotificationIntent({
    required this.type,
    this.requestId,
    this.eventId,
  });

  final String type;
  final int? requestId;
  final int? eventId;

  bool get opensFriendRequests =>
      type == 'friend_request' || type == 'friend_response';

  static PushNotificationIntent? fromMessage(RemoteMessage message) {
    final type = message.data['type']?.trim();
    if (type == null || type.isEmpty) return null;
    return PushNotificationIntent(
      type: type,
      requestId: _parseInt(message.data['request_id']),
      eventId: _parseInt(message.data['event_id']),
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class PushNotificationService {
  PushNotificationService._({
    FirebaseMessagingSupportChecker? messagingSupported,
  }) : _messagingSupported = messagingSupported ?? isFirebaseMessagingSupported;

  @visibleForTesting
  factory PushNotificationService.testing({
    FirebaseMessagingSupportChecker? messagingSupported,
  }) {
    return PushNotificationService._(messagingSupported: messagingSupported);
  }

  static final PushNotificationService instance = PushNotificationService._();

  static const String _androidChannelId = 'fiestaaa_fcm';
  static const String _androidChannelName = 'Notifications';
  static const String _androidChannelDescription = 'Fiestaaa notifications';

  late final FirebaseMessaging _messaging;
  final FirebaseMessagingSupportChecker _messagingSupported;
  final NotificationsApi _api = NotificationsApi();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _cachedToken;
  String? _registeredToken;
  SessionData? _session;
  StreamSubscription<String>? _tokenStreamSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  Timer? _syncRetryTimer;
  bool _syncInProgress = false;
  int _syncRetryAttempt = 0;
  bool _blocked = false;
  final StreamController<PushNotificationIntent> _intentController =
      StreamController<PushNotificationIntent>.broadcast();

  Stream<PushNotificationIntent> get intents => _intentController.stream;

  @visibleForTesting
  bool get isBlocked => _blocked;

  @visibleForTesting
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (!await _canUseFirebaseMessaging()) {
        _blockPushNotifications();
        return;
      }

      _messaging = FirebaseMessaging.instance;
      _initialized = true;

      await _messaging.setAutoInitEnabled(true);
      await _requestPermissions();
      await _initLocalNotifications();
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((message) {
        _ignoreAsyncErrors(_handleForegroundMessage(message));
      });
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _emitIntentFromMessage,
      );

      _cachedToken = await _safeGetToken();
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _emitIntentFromMessage(initialMessage);
      }
      _tokenStreamSub = _messaging.onTokenRefresh.listen((token) {
        _ignoreAsyncErrors(_handleTokenRefresh(token));
      });
    } catch (_) {
      _blockPushNotifications();
    }
  }

  Future<bool> _canUseFirebaseMessaging() async {
    try {
      return await _messagingSupported();
    } catch (_) {
      return false;
    }
  }

  void _blockPushNotifications() {
    _initialized = true;
    _blocked = true;
  }

  void _ignoreAsyncErrors(Future<void> future) {
    unawaited(future.catchError((_) {}));
  }

  Future<void> _handleTokenRefresh(String token) async {
    final previous = _cachedToken;
    _cachedToken = token;
    if (_session != null) {
      await _syncRegisteredDevice(
        oldTokenOverride: previous != token ? previous : null,
      );
    }
  }

  Future<void> syncSession(SessionData session) async {
    _session = session;
    if (!_initialized) {
      await init();
    }
    if (_blocked) return;
    await _syncRegisteredDevice();
  }

  Future<void> _syncRegisteredDevice({String? oldTokenOverride}) async {
    if (_blocked || _syncInProgress) return;
    final session = _session;
    if (session == null) return;

    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;

    _syncInProgress = true;
    try {
      final token = _cachedToken ?? await _safeGetToken();
      if (token == null) {
        _scheduleSyncRetry();
        return;
      }

      if (_registeredToken == token && oldTokenOverride == null) return;

      try {
        final oldToken = oldTokenOverride ?? _registeredToken;
        if (oldToken != null && oldToken != token) {
          await _api.refreshDevice(
            authToken: session.token,
            oldToken: oldToken,
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
        _syncRetryAttempt = 0;
      } catch (_) {
        _scheduleSyncRetry();
      }
    } finally {
      _syncInProgress = false;
    }
  }

  void _scheduleSyncRetry() {
    if (_session == null || _blocked || _syncRetryTimer?.isActive == true) {
      return;
    }

    final seconds = switch (_syncRetryAttempt) {
      0 => 2,
      1 => 5,
      2 => 10,
      _ => 30,
    };
    _syncRetryAttempt += 1;
    _syncRetryTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_syncRegisteredDevice());
    });
  }

  Future<void> clearSession() async {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
    _syncRetryAttempt = 0;
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
    _syncRetryTimer?.cancel();
    await _tokenStreamSub?.cancel();
    await _openedAppSub?.cancel();
  }

  void _emitIntentFromMessage(RemoteMessage message) {
    final intent = PushNotificationIntent.fromMessage(message);
    if (intent == null || _intentController.isClosed) return;
    _intentController.add(intent);
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      _blocked = settings.authorizationStatus == AuthorizationStatus.denied;
    } catch (_) {
      // Permission request failed (blocked); continue without notifications.
      _blocked = true;
    }
  }

  Future<String?> _safeGetToken() async {
    try {
      if (!await _hasApnsTokenIfNeeded()) return null;
      return await _messaging.getToken(
        vapidKey: kIsWeb && fcmWebVapidKey.isNotEmpty ? fcmWebVapidKey : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasApnsTokenIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;

    try {
      final apnsToken = await _messaging.getAPNSToken();
      return apnsToken != null && apnsToken.isNotEmpty;
    } catch (_) {
      return true;
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
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings: initSettings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _androidChannelId,
            _androidChannelName,
            description: _androidChannelDescription,
            importance: Importance.high,
          ),
        );
        await androidPlugin.requestNotificationsPermission();
      }
    }
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
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      id: notif.hashCode,
      title: notif.title,
      body: notif.body,
      notificationDetails: details,
    );
  }
}
