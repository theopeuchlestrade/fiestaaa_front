# Fiestaaa Front

Frontend Flutter de Fiestaaa, une application d'organisation d'événements
privés.

L'application couvre l'authentification, la création d'événements, les
invitations, les listes d'items, le covoiturage, les frais partagés, les QR
codes d'accès, les notifications push et les préférences utilisateur.

## Stack

- Flutter 3.41.5
- Dart 3.11
- Firebase pour la configuration mobile/web et les notifications
- Google Sign-In et Sign in with Apple
- Docker/Nginx pour le build web de production

## Prérequis

- Flutter SDK compatible avec `pubspec.yaml`
- Dart SDK fourni par Flutter
- Une copie locale de `.env.example` vers `.env`

## Configuration

```bash
cp .env.example .env
```

Les valeurs de `.env.example` sont des placeholders. Les vraies valeurs
Firebase, OAuth, VAPID, signing Android et fichiers `google-services.json`
doivent rester dans `.env`, dans les secrets CI ou dans les stores de secrets
adaptés.

Variables principales :

- `FIESTAAA_API_BASE_URL` : URL du backend
- `FIESTAAA_APP_BASE_URL` : URL publique du front
- `FIESTAAA_GOOGLE_WEB_CLIENT_ID` : client OAuth web
- `FIESTAAA_APPLE_*` : configuration Apple Sign-In
- `FIESTAAA_FCM_VAPID_KEY` : clé VAPID web push
- `FIREBASE_*` : configuration Firebase web/mobile

En développement web local, utilisez le même host pour le front et l'API.
Par exemple, utilisez `localhost:5001` avec
`FIESTAAA_API_BASE_URL=http://localhost:8080`, et évitez de mélanger
`localhost` et `127.0.0.1`, sinon les cookies `HttpOnly` ne seront pas envoyés
comme prévu.

## Développement local

Installer les dépendances et générer les localisations :

```bash
flutter pub get
flutter gen-l10n
```

Web :

```bash
flutter run -d chrome --web-port=5001 --dart-define-from-file=.env
```

Android :

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env
```

## Firebase web service worker

Le service worker Firebase web est généré depuis
`web/firebase-messaging-sw.template.js` et `.env`.

```bash
dart run tool/generate_firebase_sw.dart
```

Le fichier généré `web/firebase-messaging-sw.js` est ignoré par Git.

## Build Android

Debug :

```bash
flutter build apk --debug --dart-define-from-file=.env
```

Release :

```bash
flutter build apk --release --dart-define-from-file=.env
```

La signature release utilise `android/key.properties` si le fichier existe,
sinon Flutter retombe sur une signature de debug. Ne committez jamais
`android/key.properties`, les keystores `.jks` ou les profils de provisioning.

## Qualité et tests

Format :

```bash
dart format --output=none --set-exit-if-changed lib test tool
```

Analyse :

```bash
flutter analyze
```

Tests :

```bash
flutter test --dart-define-from-file=.env
```

Pour un clone frais, la séquence recommandée est :

```bash
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --dart-define-from-file=.env
```

## Déploiement

Le build web de production est défini dans `Dockerfile` et servi par Nginx.
Le workflow GitHub Actions publie l'image GHCR et déclenche le déploiement.

La documentation d'exploitation vit dans le dépôt backend compagnon,
`fiestaaa_back/docs/deploiement.md`.

## Sécurité

Ne signalez pas de vulnérabilité via une issue publique. Consultez
`SECURITY.md` pour le canal de signalement et les attentes de divulgation.

Avant toute publication publique du dépôt, relancez un scan de secrets sur
l'état courant et sur tout l'historique Git.

## Licence

`fiestaaa_front` est distribué sous licence `MPL-2.0`. Voir `LICENSE`.
