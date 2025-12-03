// ignore_for_file: constant_identifier_names

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REDACTED_FIREBASE_API_KEY',
    appId: '1:900475997784:web:c84668179aa61dbac6042d',
    messagingSenderId: '900475997784',
    projectId: 'fiestaaa-app',
    storageBucket: 'fiestaaa-app.firebasestorage.app',
    measurementId: 'G-0TGSYBMDZ6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REDACTED_FIREBASE_API_KEY',
    appId: '1:900475997784:android:1dcbb678edfc55c5c6042d',
    messagingSenderId: '900475997784',
    projectId: 'fiestaaa-app',
    storageBucket: 'fiestaaa-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REDACTED_FIREBASE_API_KEY',
    appId: '1:900475997784:ios:d352453a29aab0efc6042d',
    messagingSenderId: '900475997784',
    projectId: 'fiestaaa-app',
    storageBucket: 'fiestaaa-app.firebasestorage.app',
    iosBundleId: 'com.fiestaaa.fiestaaa',
  );
}
