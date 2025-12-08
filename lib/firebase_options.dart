// ignore_for_file: constant_identifier_names

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

const String firebaseProjectId =
    String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
const String firebaseStorageBucket =
    String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
const String firebaseMessagingSenderId =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');

const String firebaseWebApiKey =
    String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
const String firebaseWebAppId =
    String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '');
const String firebaseWebMeasurementId =
    String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID', defaultValue: '');

const String firebaseAndroidApiKey =
    String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: '');
const String firebaseAndroidAppId =
    String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');

const String firebaseIosApiKey =
    String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: '');
const String firebaseIosAppId =
    String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');
const String firebaseIosBundleId =
    String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: '');

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _requireConfig(web, 'web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _requireConfig(android, 'android');
      case TargetPlatform.iOS:
        return _requireConfig(ios, 'ios');
      default:
        return _requireConfig(web, 'web');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: firebaseWebApiKey,
    appId: firebaseWebAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket,
    measurementId: firebaseWebMeasurementId,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: firebaseAndroidApiKey,
    appId: firebaseAndroidAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: firebaseIosApiKey,
    appId: firebaseIosAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket,
    iosBundleId: firebaseIosBundleId,
  );

  static FirebaseOptions _requireConfig(
    FirebaseOptions options,
    String platform,
  ) {
    if (options.apiKey.isEmpty ||
        options.appId.isEmpty ||
        options.projectId.isEmpty ||
        options.messagingSenderId.isEmpty ||
        (platform == 'ios' && options.iosBundleId?.isEmpty == true)) {
      throw StateError(
        'Firebase non configuré pour $platform: fournissez les dart-defines FIREBASE_* requis.',
      );
    }
    return options;
  }
}
