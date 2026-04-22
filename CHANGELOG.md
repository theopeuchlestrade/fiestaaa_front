# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added a full authentication flow with persisted sessions, login, registration, email verification, logout, and share-link handling at app startup.
- Added Google and Apple OAuth flows when runtime configuration is provided.
- Added primary app pages for the home screen, event list, event detail, event creation, and event editing.
- Added front-end support for event features including carpools, polls, items, shared playlists, payments, shared expenses, and ticketing.
- Added invitation flows for personal invitations, invitation responses, event-level invitation management, and share links.
- Added friend flows for search, friend requests, accept/decline actions, and integration with invitation screens.
- Added carpool flows for creation, listing, joining, leaving, and deep links to Google Maps and Apple Maps.
- Added event item flows with scope filters, reservations, and contribution tracking.
- Added shared expense flows with creation, listing, balance summaries, and settlement suggestions.
- Added QR flows with a personal QR page, an owner scanner, and check-in result displays.
- Added a profile page with handle, avatar, and account-related actions.
- Added web/mobile push notification support and device registration flows.
- Added localization support through `flutter gen-l10n` and the app theming layer.

### Changed
- Changed `flutter gen-l10n` to be part of the local workflow, CI, and Docker builds.
- Changed deployment workflows to use immutable image tags and public smoke checks after rollout.
- Changed the production web build path so it works on a fresh clone just like CI.
- Changed the production Nginx CSP to tighten allowed `connect-src` and `img-src` origins.

### Security
- Removed sensitive URL parameters such as `shareToken` and `verifyEmailToken` after they are processed in the app.
- Hardened external URL guards to reject `localhost`, private IPs, and local-network targets.
- Restricted the production CSP so it no longer allows local origins such as `localhost` or `127.0.0.1`.
