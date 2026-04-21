# Contributing to fiestaaa_front

Merci de contribuer au front.

## Prérequis
- Flutter SDK (version utilisée par le projet)
- Dart SDK

## Installation
1. Copier `.env.example` en `.env` si nécessaire.
2. `flutter pub get`
3. `flutter gen-l10n`

## Lancer l’app
- Web : `flutter run -d chrome --web-port=5001 --dart-define-from-file=.env`
- Android : `flutter run -d emulator-5554 --dart-define-from-file=.env`

## Pre-commit (hooks locaux)
Les hooks exécutent `flutter gen-l10n`, `dart format` puis `flutter analyze`.

Installer les hooks :
- Depuis ce repo : `sh scripts/install-hooks.sh`
- Depuis la racine mono-repo : `sh scripts/install-hooks.sh`

## Lint / Format
- `dart format lib test`
- `flutter gen-l10n`
- `flutter analyze`

## Tests
- `flutter test --dart-define-from-file=.env`

## PR / MR
- Décrire le contexte, le changement, et l’impact.
- Vérifier `flutter gen-l10n`, `dart format`, `flutter analyze` et `flutter test --dart-define-from-file=.env` avant d’ouvrir la MR.
- Les vulnérabilités de sécurité ne doivent pas être remontées via une issue publique ; suivre `SECURITY.md`.
