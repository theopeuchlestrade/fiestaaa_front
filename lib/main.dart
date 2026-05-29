import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fiestaaa_front/firebase_options.dart';
import 'package:fiestaaa_front/src/app.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.init();
  await initializeDateFormatting('fr_FR');
  runApp(const FiestaaaApp());
}

Future<void> main() async {
  if (sentryDsn.isEmpty) {
    await _bootstrap();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = sentryDsn;
    options.environment = sentryEnvironment;
    if (sentryRelease.isNotEmpty) {
      options.release = sentryRelease;
    }
    options.tracesSampleRate = sentryTracesSampleRate;
    options.sendDefaultPii = false;
  }, appRunner: _bootstrap);
}
