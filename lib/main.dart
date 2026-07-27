import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fiestaaa_front/firebase_options.dart';
import 'package:fiestaaa_front/src/app.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

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
  tz.initializeTimeZones();
  var firebaseReady = false;
  try {
    await _timedStartup(
      'Firebase.initializeApp',
      () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    );
    firebaseReady = true;
  } catch (error) {
    debugPrint('Fiestaaa startup Firebase.initializeApp failed: $error');
  }
  if (firebaseReady && !kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  try {
    await _timedStartup(
      'initializeDateFormatting',
      () => initializeDateFormatting(),
    );
  } catch (error) {
    debugPrint('Fiestaaa startup initializeDateFormatting failed: $error');
  }
  runApp(const FiestaaaApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
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
