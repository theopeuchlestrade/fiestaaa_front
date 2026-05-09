# Contributing to fiestaaa_front

Thanks for contributing to the frontend.

## Prerequisites
- Flutter SDK (the version used by the project)
- Dart SDK

## Installation
1. Copy `.env.example` to `.env` if needed.
2. `flutter pub get`
3. `flutter gen-l10n`

## Run the App
- Web: `flutter run -d chrome --web-port=5001 --dart-define-from-file=.env`
- Android: `flutter run -d emulator-5554 --dart-define-from-file=.env`

## Pre-commit (Local Hooks)
The hooks run `flutter gen-l10n`, `dart format`, then `flutter analyze`.

Install the hooks:
- From this repo: `sh scripts/install-hooks.sh`
- From the mono-repo root: `sh scripts/install-hooks.sh`

## Lint / Format
- `dart format lib test`
- `flutter gen-l10n`
- `flutter analyze`

## Tests
- `flutter test --dart-define-from-file=.env`

## PR / MR
- Describe the context, change, and impact.
- Verify `flutter gen-l10n`, `dart format`, `flutter analyze`, and `flutter test --dart-define-from-file=.env` before opening the MR.
- Update `CHANGELOG.md` for any notable releasable, user-facing, security, production infrastructure, or DX change.
- Security vulnerabilities must not be reported through a public issue; follow `SECURITY.md`.
