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

### Android (Émulateur)

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env
```

## Build APK (Android)

### Build Debug

Pour développer et tester :
```bash
flutter build apk --debug --dart-define-from-file=.env
```

L'APK sera généré dans : `build/app/outputs/flutter-apk/app-debug.apk`

### Build Release

Pour distribution (installation directe, test de prod, etc.) :
```bash
flutter build apk --release --dart-define-from-file=.env
```

L'APK sera généré dans : `build/app/outputs/flutter-apk/app-release.apk`

> **Note** : Par défaut, les builds release utilisent la signature de debug. Voir la section ci-dessous pour configurer une signature de production.

## Signature de l'APK (Keystore)

### Configuration actuelle

Le projet est configuré pour utiliser un keystore de production personnalisé via `android/key.properties`.

- Si `android/key.properties` existe : utilise le keystore de production (`android/fiestaaa-release.jks`)
- Sinon : fallback vers le keystore de debug (`~/.android/debug.keystore`)

### Créer un keystore de production (signature personnalisée)

⚠️ **IMPORTANT** : Créez et sauvegardez soigneusement le keystore et ses mots de passe. Sans ces informations, il sera impossible de signer les futures mises à jour de l'app.

#### 1. Créer le keystore

Ouvrez un terminal dans le dossier `android/` du projet :

```bash
cd android

keytool -genkey -v -keystore fiestaaa-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fiestaaa
```

Vous devrez répondre aux questions :
- **Keystore password** : Choisissez un mot de passe fort (⚠️ NOTEZ-LE BIEN)
- **Re-enter new password** : Réécrivez le mot de passe
- **What is your first and last name?** : Votre nom
- **What is the name of your organizational unit?** : (laissez vide)
- **What is the name of your organization?** : Fiestaaa
- **What is the name of your City or Locality?** : Votre ville
- **What is the name of your State or Province?** : Votre région
- **What is the two-letter country code?** : FR (ou autre)
- **Alias password** : Choisissez un mot de passe (⚠️ NOTEZ-LE BIEN)

#### 2. Remplir le fichier `android/key.properties`

Créez/modifiez le fichier `android/key.properties` avec vos informations :

```properties
# Mot de passe du keystore
storePassword=VOTRE_MOT_DE_PASSE_KESTORE

# Mot de passe de l'alias
keyPassword=VOTRE_MOT_DE_PASSE_ALIAS

# Alias de la clé
keyAlias=fiestaaa

# Chemin relatif vers le fichier de keystore (le plus courant : dans android/)
storeFile=fiestaaa-release.jks
```

#### 3. Générer l'APK signé

```bash
flutter build apk --release --dart-define-from-file=.env
```

L'APK sera signé avec votre keystore personnalisé.

#### 4. Vérifier la signature

```bash
keytool -list -v -keystore android/fiestaaa-release.jks
```

Ou avec `apksigner` (sur Windows PowerShell) :
```powershell
& 'C:\Users\Diego\AppData\Local\Android\Sdk\build-tools\36.1.0\apksigner.bat' verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

### Sécurité - Bonnes pratiques

- ✅ **Sauvegardez** le fichier `fiestaaa-release.jks` en plusieurs endroits sécurisés (Google Drive, disque externe, cloud crypté)
- ✅ **Documentez** les mots de passe (KeePass, Bitwarden, etc.)
- ✅ **Ne committez JAMAIS** `key.properties` ni `.jks` (déjà dans `.gitignore`)
- ✅ **Conservez les fingerprints** SHA-1 et SHA-256 pour vérification

> Si vous perdez le keystore ou les mots de passe, il sera impossible de signer les futures mises à jour de l'app. Dans ce cas, il faudra créer un nouveau keystore, mais cela posera des problèmes si l'app a déjà été publiée sur un store (Google Play, etc.).

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

### Commandes locales recommandées

Pour éviter les erreurs sur clone frais ou en CI locale, exécute explicitement :

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test --dart-define-from-file=.env
```

### Quoi committer / quoi ignorer

À committer : `lib/l10n/*.arb` + `l10n.yaml` (et éventuellement `untranslated.txt`).

À ignorer : les fichiers générés `lib/l10n/app_localizations*.dart` (gérés dans `.gitignore`).

## Firebase config & service worker (Web)

1. Créez un fichier `.env` à la racine avec les clés Firebase web et OAuth :
  ```bash
  FIESTAAA_API_BASE_URL=http://localhost:8080
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
2. En web, utilisez le meme host pour le front et l'API pendant le dev local.
   Exemple: `localhost:5001` avec `FIESTAAA_API_BASE_URL=http://localhost:8080`.
   N'utilisez pas `localhost` pour le front et `127.0.0.1` pour l'API, sinon le cookie de session `HttpOnly` ne sera pas renvoye.

3. Générez le service worker avant `flutter build web` :
  ```bash
  dart run tool/generate_firebase_sw.dart
  ```
  Cela produit `web/firebase-messaging-sw.js` à partir de `web/firebase-messaging-sw.template.js` et de votre `.env`.

4. Les mêmes valeurs doivent être passées en `--dart-define` (voir commandes ci-dessus) pour correspondre à `lib/firebase_options.dart`.

> `web/firebase-messaging-sw.js` est ignoré par git : conservez les secrets uniquement dans `.env`/CI.

## Security

- Report policy: `SECURITY.md`
- Public-release transition runbook: see `fiestaaa_back/docs/passage-public-open-source.md` in the companion backend repo.

## License

`fiestaaa_front` is licensed under `MPL-2.0`. See `LICENSE`.
