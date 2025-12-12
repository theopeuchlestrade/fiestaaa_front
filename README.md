# fiestaaa_front

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Run the app

### Web

```bash
flutter run -d chrome --web-port=5001 --dart-define-from-file=.env
```

### Android

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env
```

## Firebase config & service worker (Web)

1. Créez un fichier `.env` à la racine avec les clés Firebase web :
  ```bash
  FIESTAAA_API_BASE_URL=http://127.0.0.1:8080
  FIESTAAA_FCM_VAPID_KEY={fcm_vapid_key}
  FIESTAAA_GOOGLE_WEB_CLIENT_ID={google_web_client_id}
  FIREBASE_PROJECT_ID=fiestaaa-app
  FIREBASE_STORAGE_BUCKET=fiestaaa-app.firebasestorage.app
  FIREBASE_MESSAGING_SENDER_ID={messaging_sender_id}
  FIREBASE_WEB_API_KEY={web_api_key}
  FIREBASE_WEB_APP_ID={web_app_id}
  FIREBASE_WEB_MEASUREMENT_ID={web_measurement}
  FIREBASE_AUTH_DOMAIN=fiestaaa-app.firebaseapp.com
  ```
2. Générez le service worker avant `flutter build web` :
  ```bash
  dart run tool/generate_firebase_sw.dart
  ```
  Cela produit `web/firebase-messaging-sw.js` à partir de `web/firebase-messaging-sw.template.js` et de votre `.env`.
3. Les mêmes valeurs doivent être passées en `--dart-define` (voir commandes ci-dessus) pour correspondre à `lib/firebase_options.dart`.

> `web/firebase-messaging-sw.js` est ignoré par git : conservez les secrets uniquement dans `.env`/CI.***
