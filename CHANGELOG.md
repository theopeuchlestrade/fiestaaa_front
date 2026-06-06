# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-05

Initial public-readiness baseline for the Fiestaaa frontend.

### Added
- Added brand/assets, code of conduct, support, and governance policies for
  public contribution readiness.
- Added a full authentication flow with persisted sessions, login, registration, email verification, registration completion, logout, and share-link handling at app startup.
- Added Google and Apple OAuth flows when runtime configuration is provided.
- Added startup handling for email-verification links, share links, and notification intents.
- Added primary app pages for the home screen, event list, event detail, event creation, and event editing.
- Added event creation/editing support for dates, optional end dates, address suggestions, invitation deadlines, feature toggles, playlist links, and payment settings.
- Added frontend support for event features including carpools, polls, item lists, shared playlists, payment links, shared expenses, and ticketing.
- Added invitation flows for personal invitations, invitation responses, event-level invitation management, guest share links, and friend-backed invite screens.
- Added friend flows for search, friend requests, accept/decline actions, friend listing, and removal.
- Added carpool flows for creation, listing, editing, joining, leaving, seat tracking, and deep links to Google Maps and Apple Maps.
- Added event item flows with scope filters, catalog items, custom items, reservations, and contribution tracking.
- Added poll flows with creation, voting, listing, and deletion.
- Added shared expense flows with creation, listing, balance summaries, and settlement suggestions.
- Added QR flows with a personal QR page, owner scanner, scan result displays, and check-in statistics.
- Added profile management with handle updates, avatar upload, and account-related actions.
- Added web/mobile push notification support and device registration, refresh, and revocation flows.
- Added Firebase web service-worker generation from environment configuration.
- Added localization support through `flutter gen-l10n` and English/French app strings.
- Added a shared app theme and responsive page layouts for mobile and desktop web.
- Added production web Docker/Nginx build support with cache-safe Flutter entry-point names.
- Added frontend CI jobs for formatting, localization generation, analysis, tests, web container builds, Android compile checks, and unsigned iOS compile checks on non-PR runs.

### Changed
- Changed the app version baseline to `0.1.0` for the first public release.
- Changed `flutter gen-l10n` to be part of the local workflow, CI, mobile build, and Docker build paths.
- Changed the production web build path so it works on a fresh clone just like CI.
- Changed the production Nginx CSP to tighten allowed `connect-src` and `img-src` origins.

### Security
- Removed sensitive URL parameters such as `shareToken` and `verifyEmailToken` after they are processed in the app.
- Hardened external URL guards to reject `localhost`, private IPs, and local-network targets.
- Restricted the production CSP so it no longer allows local origins such as `localhost` or `127.0.0.1`.
- Kept Firebase, OAuth, VAPID, signing, and provisioning values out of tracked files and routed them through local env files or GitHub secrets.
- Added secret scanning, security policy, dependency review, provenance attestation, and public-opening documentation for open-source readiness.
