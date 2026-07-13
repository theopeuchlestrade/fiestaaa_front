# Architecture

Fiestaaa Front is the Flutter client for the public Fiestaaa application. It
targets web and mobile from the same codebase and consumes the companion Rust
backend API.

## Runtime Shape

- Flutter renders the authenticated app, event workflows, invitations, QR
  screens, shared expenses, carpools, polls, item lists, and profile pages.
- The backend owns authentication sessions, event data, invitations, realtime
  streams, notification registration, media URLs, and permission checks.
- PostgreSQL and Redis are backend services; the frontend never connects to
  them directly.
- Firebase is used for web/mobile push notification configuration and delivery.
- Google and Apple OAuth are optional runtime integrations enabled through
  `.env` / `--dart-define` values.

## Configuration

Local and CI builds use `.env`-style dart defines. Do not commit `.env`,
Firebase private files, signing material, provisioning profiles, or store
credentials.

The generated Firebase service worker comes from
`web/firebase-messaging-sw.template.js` and local environment values. The
generated `web/firebase-messaging-sw.js` file is ignored.

The frontend pins the backend OpenAPI snapshot hash in
`tool/backend_openapi_contract.json`. CI compares it with the backend `main`
branch so contract changes require an explicit frontend compatibility review.

## Public vs Private Operations

This repository contains the frontend source, local build instructions,
quality checks, public CI, and production-style web container build. Official
mobile signing, release signing, deployment, observability, and rollback
operations are maintained outside the public source repository.
