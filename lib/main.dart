import 'dart:async';

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

Future<T> _timedStartup<T>(String label, Future<T> Function() action) async {
  final watch = Stopwatch()..start();
  try {
    return await action();
  } finally {
    debugPrint('Fiestaaa startup $label: ${watch.elapsedMilliseconds}ms');
  }
}

Future<void> _bootstrap() async {
  final startupWatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  await _timedStartup(
    'Firebase.initializeApp',
    () =>
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _timedStartup(
    'initializeDateFormatting',
    () => initializeDateFormatting('fr_FR'),
  );
  runApp(const FiestaaaApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      _timedStartup(
        'PushNotificationService.init',
        PushNotificationService.instance.init,
      ),
    );
    debugPrint(
      'Fiestaaa startup first frame scheduled after '
      '${startupWatch.elapsedMilliseconds}ms',
    );
  });
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
