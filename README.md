# 🎉 Fiestaaa Front

<img src=".github/assets/fiestaaa_logo.png" alt="Fiestaaa Logo" width="120">

[![Frontend Release](https://github.com/theopeuchlestrade/fiestaaa_front/actions/workflows/deploy.yml/badge.svg)](https://github.com/theopeuchlestrade/fiestaaa_front/actions/workflows/deploy.yml)
[![CI](https://github.com/theopeuchlestrade/fiestaaa_front/actions/workflows/ci.yml/badge.svg)](https://github.com/theopeuchlestrade/fiestaaa_front/actions/workflows/ci.yml)
[![Flutter 3.41.5](https://img.shields.io/badge/Flutter-3.41.5-02569B.svg?logo=flutter)](https://flutter.dev)
[![Dart 3.11](https://img.shields.io/badge/Dart-3.11-0175C2.svg?logo=dart)](https://dart.dev)
[![MPL-2.0 License](https://img.shields.io/badge/license-MPL--2.0-brightgreen.svg)](LICENSE)
[![Firebase](https://img.shields.io/badge/firebase-ready-FFCA28.svg?logo=firebase)](https://firebase.google.com)

**Fiestaaa Frontend** — The Flutter app for organizing private events with friends and family.

---

## 📖 Table of Contents

- [✨ Features](#-features)
- [🚀 Getting Started](#-getting-started)
- [🔧 Development](#-development)
- [📦 Build & Deployment](#-build--deployment)
- [🔒 Security](#-security)
- [📜 License](#-license)
- [🤝 Contributing](#-contributing)

---

## ✨ Features

- **Authentication**: Google Sign-In, Sign in with Apple, and email/password
- **Event Creation**: Full event management with custom details
- **Invitations**: Send and manage invites with email
- **Item Lists**: Collaborative shopping lists
- **Carpools**: Organize rides with participants
- **Shared Expenses**: Track and split expenses among attendees
- **Access QR Codes**: Secure entry management
- **Push Notifications**: Real-time updates via FCM
- **User Preferences**: Customize your experience

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK compatible with `pubspec.yaml`
- Dart SDK provided by Flutter

### Quick Start

1. Clone the repository and copy the environment file:
   ```bash
   git clone https://github.com/theopeuchlestrade/fiestaaa_front.git
   cd fiestaaa_front
   cp .env.example .env
   ```

2. Configure your environment variables in `.env`. Required variables include:
   - `FIESTAAA_API_BASE_URL`: Backend API URL
   - `FIESTAAA_APP_BASE_URL`: Public frontend URL
   - `FIESTAAA_GOOGLE_WEB_CLIENT_ID`: Web OAuth client ID
   - `FIESTAAA_APPLE_*`: Apple Sign-In configuration
   - `FIESTAAA_FCM_VAPID_KEY`: Web push VAPID key
   - `FIRESTORE_*`: Firebase configuration

3. Install dependencies and generate localizations:
   ```bash
   flutter pub get
   flutter gen-l10n
   ```

4. Run the app:
   - **Web:**
     ```bash
     flutter run -d chrome --web-port=5001 --dart-define-from-file=.env
     ```
   - **Android:**
     ```bash
     flutter run -d emulator-5554 --dart-define-from-file=.env
     ```

> **Note**: In local web development, use the same host for frontend and API (e.g., `localhost:5001` with `FIESTAAA_API_BASE_URL=http://localhost:8080`). Avoid mixing `localhost` and `127.0.0.1`; otherwise, `HttpOnly` cookies will not be sent correctly.

---

## 🔧 Development

### Firebase Web Service Worker

The Firebase web service worker is generated from `web/firebase-messaging-sw.template.js` and `.env`:

```bash
dart run tool/generate_firebase_sw.dart
```

The generated `web/firebase-messaging-sw.js` file is ignored by Git.

### Quality and Tests

**Format:**
```bash
dart format --output=none --set-exit-if-changed lib test tool
```

**Analyze:**
```bash
flutter analyze
```

**Tests:**
```bash
flutter test --dart-define-from-file=.env
```

**Fresh clone sequence:**
```bash
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --dart-define-from-file=.env
```

---

## 📦 Build & Deployment

### Android Build

**Debug:**
```bash
flutter build apk --debug --dart-define-from-file=.env
```

**Release:**
```bash
flutter build apk --release --dart-define-from-file=.env
```

Release signing uses `android/key.properties` if the file exists; otherwise, Flutter falls back to debug signing. **Never commit** `android/key.properties`, `.jks` keystores, or provisioning profiles.

### iOS Build

**Local development on connected iPhone:**
```bash
flutter run -d <device-id> --dart-define-from-file=.env
```

**Manual IPA build:**
The `Manual Build iOS IPA` workflow creates a signed `.ipa` artifact for device testing.

**Frontend Release workflow** uses the same reusable iOS build and attaches the `.ipa` to the GitHub Release. Required production secrets:
- `IOS_CERTIFICATE_BASE64`: base64-encoded `.p12` signing certificate
- `IOS_CERTIFICATE_PASSWORD`: `.p12` password
- `IOS_PROVISIONING_PROFILE_BASE64`: base64-encoded `.mobileprovision`
- `IOS_TEAM_ID`: Optional if provisioning profile contains the team ID
- `IOS_CODE_SIGN_IDENTITY`: Optional, defaults to `Apple Development` for debugging exports

Use `debugging` with a development provisioning profile, or `release-testing` with an Ad Hoc profile. The iPhone must be included in the provisioning profile.

### Web Production Build

The production web build is defined in `Dockerfile` and served by Nginx.

### Release Workflow

The **Frontend Release** GitHub Actions workflow:
- ✅ Verifies the app
- 📦 Derives the next version from the latest `vX.Y.Z` tag or custom version
- 🔖 Creates a tag-only release commit with `pubspec.yaml` bumped
- 🐳 Publishes the GHCR web image
- 📱 Builds Android/iOS artifacts
- 📝 Creates the GitHub Release
- 🚀 Can deploy the web image to the VPS

It does **not** push directly to `main`, so it remains compatible with strict branch protection.

### Release Changelogs

Release changelogs are generated automatically from commits on `main` between SemVer tags. Use clear Gitmoji or Conventional Commit-style PR titles for useful `CHANGELOG.md` and GitHub Release notes.

### Operations Documentation

Full operations documentation is available in the companion backend repository: [fiestaaa_back/docs/deploiement.md](https://github.com/theopeuchlestrade/fiestaaa_back/blob/main/docs/deploiement.md)

---

## 🔒 Security

⚠️ **Do not report vulnerabilities through public issues.**

See [`SECURITY.md`](SECURITY.md) for the reporting channel and disclosure expectations.

### Security Scans

Before any public release, rerun a secret scan on the current state and full Git history.

CI runs:
- Workflow linting
- Dockerfile checks
- Full-history Gitleaks scan on pull requests and pushes to `main`

---

## 📜 License

`fiestaaa_front` is distributed under the **[MPL-2.0](LICENSE)** license.

This license covers the frontend source code. Fiestaaa brand assets, app icons, screenshots, and third-party logos are handled separately in [`TRADEMARKS.md`](TRADEMARKS.md).

---

## 🤝 Contributing

We welcome contributions! Please see:

- **Contributions**: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- **Code of Conduct**: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- **Support**: [`SUPPORT.md`](SUPPORT.md)
- **Governance**: [`GOVERNANCE.md`](GOVERNANCE.md)
- **Brand & Assets**: [`TRADEMARKS.md`](TRADEMARKS.md)

### Companion Repository

- 🔗 [Fiestaaa Backend](https://github.com/theopeuchlestrade/fiestaaa_back) — Rust API and server
