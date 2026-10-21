# Contributing to fiestaaa_front

Thanks for contributing to the frontend.

## Prerequisites
- Flutter SDK 3.47.7 (matching CI and Docker)
- Dart SDK 3.13.5, provided by Flutter
- Temurin JDK 25 LTS for Android builds (see `.java-version`)
- Node.js 22 LTS for repository tooling (see `.nvmrc`)

## Installation
1. Copy `.env.example` to `.env` if needed.
2. `flutter pub get`
3. `flutter gen-l10n`
4. Select JDK 25 in `JAVA_HOME` and Android Studio's Gradle JDK settings.
   Set Flutter to the same JDK with `flutter config --jdk-dir "$JAVA_HOME"`.
   After the first Android build generates the Gradle wrapper,
   `cd android && ./gradlew --version` must report a Java 25 launcher and daemon.
   Java/Kotlin source and bytecode targets remain 17 for Android compatibility.

For a guided first setup, use [`docs/first-contribution.md`](docs/first-contribution.md).

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
- Markdown links: `ruby scripts/check_markdown_links.rb`

## Project Policies
- Follow `CODE_OF_CONDUCT.md` in project spaces.
- Read `SUPPORT.md` before opening support-style issues.
- Read `GOVERNANCE.md` for the maintainer-led decision model.
- Read `ROADMAP.md` before proposing large feature work.
- Changes touching the Fiestaaa name, public copy, screenshots, app icons,
  logos, or third-party marks must follow `TRADEMARKS.md`.

## PR / MR
- Describe the context, change, and impact.
- Verify `flutter gen-l10n`, `dart format`, `flutter analyze`, `flutter test --dart-define-from-file=.env`, and `ruby scripts/check_markdown_links.rb` before opening the MR.
- Use a PR title or squash commit message that can become a clear release note.
  Prefer Conventional Commit titles, for example:
  - `feat(events): add item reservations`
  - `fix(auth): refresh OAuth state`
  - `security(auth): harden token validation`
  - `chore(deps): bump Flutter dependencies`
- `CHANGELOG.md` is generated automatically during the release workflow from
  commits on `main`; only edit it manually for historical corrections.
- Security vulnerabilities must not be reported through a public issue; follow `SECURITY.md`.
