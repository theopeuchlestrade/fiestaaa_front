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

## Localizations (i18n / l10n)

Ce projet utilise `flutter gen-l10n` avec :
- fichiers ARB dans `lib/l10n/`
- configuration dans `l10n.yaml`

### Génération automatique (configuration actuelle)

Dans `pubspec.yaml`, on a activé :

```yaml
flutter:
  generate: true
```

Avec ça, Flutter régénère automatiquement les fichiers de localisations lors de commandes comme `flutter pub get`, `flutter run`, `flutter build`, etc.

### Génération manuelle (optionnel)

Si tu préfères générer uniquement à la demande :
1. retire `flutter: generate: true` (ou mets-le à `false`) dans `pubspec.yaml`
2. lance la génération manuellement :

```bash
flutter gen-l10n
```

### Quoi committer / quoi ignorer

À committer : `lib/l10n/*.arb` + `l10n.yaml` (et éventuellement `untranslated.txt`).

À ignorer : les fichiers générés `lib/l10n/app_localizations*.dart` (gérés dans `.gitignore`).

## Firebase config & service worker (Web)

1. Créez un fichier `.env` à la racine avec les clés Firebase web et OAuth :
  ```bash
  FIESTAAA_API_BASE_URL=http://127.0.0.1:8080
  FIESTAAA_APPLE_SERVICE_ID=com.fiestaaa.web
  FIESTAAA_APPLE_REDIRECT_URI=http://localhost:5001/
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
