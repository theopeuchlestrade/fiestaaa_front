# First Contribution

This guide gets a fresh frontend checkout to a useful local state for a small
documentation, UI, or test contribution.

## 1. Prepare the Backend

Run the backend locally first so the app has an API to call:

```bash
git clone https://github.com/theopeuchlestrade/fiestaaa_back.git
cd fiestaaa_back
cp .env.example .env
docker compose up --build
```

In another terminal, create a local user if needed:

```bash
cargo run --bin create_local_user -- --email test@local.dev --password changeme --handle test_local
```

## 2. Run the Frontend

```bash
git clone https://github.com/theopeuchlestrade/fiestaaa_front.git
cd fiestaaa_front
cp .env.example .env
flutter pub get
flutter gen-l10n
flutter run -d chrome --web-port=5001 --dart-define-from-file=.env
```

Use the same host consistently for frontend and backend during web
development. For example, keep the frontend on `localhost:5001` and
`FIESTAAA_API_BASE_URL=http://localhost:8080`.

## 3. Verify One Small Change

Before opening a pull request, run the checks relevant to the change:

```bash
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --dart-define-from-file=.env
```

For docs-only changes, a careful local read-through is enough unless the change
touches commands, configuration, or generated files.
