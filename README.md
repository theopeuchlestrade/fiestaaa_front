# Fiestaaa Front

Fiestaaa's Flutter frontend, an app for organizing private events.

The app covers authentication, event creation, invitations, item lists,
carpools, shared expenses, access QR codes, push notifications, and user
preferences.

## Stack

- Flutter 3.41.5
- Dart 3.11
- Firebase for mobile/web configuration and notifications
- Google Sign-In and Sign in with Apple
- Docker/Nginx for the production web build

## Prerequisites

- Flutter SDK compatible with `pubspec.yaml`
- Dart SDK provided by Flutter
- A local copy of `.env.example` as `.env`

## Configuration

```bash
cp .env.example .env
```

The values in `.env.example` are placeholders. Real Firebase, OAuth, VAPID,
Android signing values, and `google-services.json` files must stay in `.env`,
CI secrets, or appropriate secret stores.

Main variables:

- `FIESTAAA_API_BASE_URL`: backend URL
- `FIESTAAA_APP_BASE_URL`: public frontend URL
- `FIESTAAA_GOOGLE_WEB_CLIENT_ID`: web OAuth client, also used on Android as the Google Sign-In `serverClientId`
- `FIESTAAA_APPLE_*`: Apple Sign-In configuration
- `FIESTAAA_FCM_VAPID_KEY`: web push VAPID key
- `FIESTAAA_SENTRY_DSN`: optional Sentry DSN for crash/error reporting
- `FIREBASE_*`: web/mobile Firebase configuration

In local web development, use the same host for the frontend and the API. For
example, use `localhost:5001` with
`FIESTAAA_API_BASE_URL=http://localhost:8080`, and avoid mixing `localhost` and
`127.0.0.1`; otherwise, `HttpOnly` cookies will not be sent as expected.

## Local Development

Install dependencies and generate localizations:

```bash
flutter pub get
flutter gen-l10n
```

Web:

```bash
flutter run -d chrome --web-port=5001 --dart-define-from-file=.env
```

Android:

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env
```

## Firebase web service worker

The Firebase web service worker is generated from
`web/firebase-messaging-sw.template.js` and `.env`.

```bash
dart run tool/generate_firebase_sw.dart
```

The generated `web/firebase-messaging-sw.js` file is ignored by Git.

## Build Android

Debug:

```bash
flutter build apk --debug --dart-define-from-file=.env
```

Release:

```bash
flutter build apk --release --dart-define-from-file=.env
```

Release signing uses `android/key.properties` if the file exists; otherwise,
Flutter falls back to debug signing. Never commit `android/key.properties`,
`.jks` keystores, or provisioning profiles.

## Build iOS

For local development on a connected iPhone:

```bash
flutter run -d <device-id> --dart-define-from-file=.env
```

The manual GitHub Actions workflow `Manual Build iOS IPA` creates a signed
`.ipa` artifact for device testing. The `Frontend Release` workflow uses the
same reusable iOS build and attaches the `.ipa` to the GitHub Release. It
requires these production environment secrets:

- `IOS_CERTIFICATE_BASE64`: base64-encoded `.p12` signing certificate
- `IOS_CERTIFICATE_PASSWORD`: `.p12` password
- `IOS_PROVISIONING_PROFILE_BASE64`: base64-encoded `.mobileprovision`
- `IOS_TEAM_ID`: optional if the provisioning profile contains the team ID
- `IOS_CODE_SIGN_IDENTITY`: optional, defaults to `Apple Development` for
  `debugging` exports and `Apple Distribution` otherwise

Use `debugging` with a development provisioning profile, or `release-testing`
with an Ad Hoc profile. In both cases, the iPhone must be included in the
provisioning profile.

## Quality and Tests

Format:

```bash
dart format --output=none --set-exit-if-changed lib test tool
```

Analyze:

```bash
flutter analyze
```

Tests:

```bash
flutter test --dart-define-from-file=.env
```

For a fresh clone, the recommended sequence is:

```bash
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --dart-define-from-file=.env
```

## Deployment

The production web build is defined in `Dockerfile` and served by Nginx. The
manual `Frontend Release` GitHub Actions workflow verifies the app, derives the
next version from the latest `vX.Y.Z` tag or from a custom version choice,
creates a tag-only release commit with `pubspec.yaml` bumped, publishes the
GHCR web image, builds Android/iOS artifacts, creates the GitHub Release, and
can deploy the web image to the VPS. It does not push directly to `main`, so it
remains compatible with strict branch protection.

Operations documentation lives in the companion backend repository,
`fiestaaa_back/docs/deploiement.md`.

## Security

Do not report vulnerabilities through a public issue. See `SECURITY.md` for the
reporting channel and disclosure expectations.

Before any public release of the repository, rerun a secret scan on the current
state and the full Git history.

## Project Policies

- Contributions: `CONTRIBUTING.md`
- Code of conduct: `CODE_OF_CONDUCT.md`
- Support expectations: `SUPPORT.md`
- Governance: `GOVERNANCE.md`
- Brand and assets: `TRADEMARKS.md`

## License

`fiestaaa_front` is distributed under the `MPL-2.0` license. See `LICENSE`.
This license covers the frontend source code. Fiestaaa brand assets, app icons,
screenshots, and third-party logos are handled separately in `TRADEMARKS.md`.
