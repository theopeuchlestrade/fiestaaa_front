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
flutter run -d chrome --web-port=5001 \
  --dart-define=FIESTAAA_API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=FIESTAAA_FCM_VAPID_KEY=your_fcm_vapid_key \
  --dart-define=FIESTAAA_GOOGLE_WEB_CLIENT_ID=your_google_web_client_id \
  --dart-define=FIREBASE_PROJECT_ID=your_project_id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your_bucket \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id \
  --dart-define=FIREBASE_WEB_API_KEY=your_web_api_key \
  --dart-define=FIREBASE_WEB_APP_ID=your_web_app_id \
  --dart-define=FIREBASE_WEB_MEASUREMENT_ID=your_web_measurement_id
```

### Android

```bash
flutter run -d emulator-5554 \
  --dart-define=FIESTAAA_API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=FIESTAAA_FCM_VAPID_KEY=your_fcm_vapid_key \
  --dart-define=FIESTAAA_GOOGLE_WEB_CLIENT_ID=your_google_web_client_id \
  --dart-define=FIREBASE_PROJECT_ID=your_project_id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your_bucket \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id \
  --dart-define=FIREBASE_ANDROID_API_KEY=your_android_api_key \
  --dart-define=FIREBASE_ANDROID_APP_ID=your_android_app_id
```

## Firebase config & service worker (Web)

1. Créez un fichier `.env` à la racine avec les clés Firebase web :
   ```
   FIREBASE_PROJECT_ID=your_project_id
   FIREBASE_STORAGE_BUCKET=your_bucket
   FIREBASE_MESSAGING_SENDER_ID=your_sender_id
   FIREBASE_WEB_API_KEY=your_web_api_key
   FIREBASE_WEB_APP_ID=your_web_app_id
   FIREBASE_WEB_MEASUREMENT_ID=your_web_measurement_id
   # optionnel si différent :
   FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
   ```
2. Générez le service worker avant `flutter build web` :
   ```bash
   dart run tool/generate_firebase_sw.dart
   ```
   Cela produit `web/firebase-messaging-sw.js` à partir de `web/firebase-messaging-sw.template.js` et de votre `.env`.
3. Les mêmes valeurs doivent être passées en `--dart-define` (voir commandes ci-dessus) pour correspondre à `lib/firebase_options.dart`.

> `web/firebase-messaging-sw.js` est ignoré par git : conservez les secrets uniquement dans `.env`/CI.***
