# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added full backend OpenAPI snapshot validation for frontend contract changes.
- Added stable invitation identifier support with a temporary email fallback
  for compatibility with older backend responses.

### Changed
- Centralized and deduplicated expired-session handling across the application.
- Moved tab and event navigation to explicit GoRouter routes and mounted event
  tabs lazily.
- Stored native sessions atomically with migration from the previous format.
- Sent the selected application locale and actual package version when
  registering push-notification devices.
- Hardened immutable Web asset caching while keeping the application shell
  revalidatable.

### Fixed
- Prevented stale asynchronous refresh responses from replacing newer state.
- Redirected safely after event deletion or access loss and avoided duplicate
  navigation after concurrent unauthorized responses.

### Dependencies
- Updated Flutter and Playwright dependencies, Nginx, Java setup, and GitHub
  Actions pins.

## [0.2.1] - 2026-07-13

### Added
- Added a pinned backend OpenAPI contract check so incompatible API changes
  require an explicit frontend review.
- Added direct data-layer coverage for profile, QR check-in, and carpool flows.

### Changed
- Derived the client-version header from application package metadata instead
  of a hard-coded version.
- Raised the enforced frontend line-coverage floor to 22 percent.

### Fixed
- Redirected malformed event deep links safely instead of throwing during route
  construction.
- Localized API and transport errors consistently without displaying raw
  backend messages.

### Dependencies
- Updated Flutter packages and the Docker, Java, and Buildx GitHub Actions.

## [0.2.0] - 2026-07-01

### Added
- Added timezone-aware event creation and editing with a searchable IANA
  timezone selector.
- Added an event trash screen with purge dates and owner restore actions.
- Added declarative deep links for authentication, events, invitations,
  friends, profile, carpools, expenses, and trash.
- Added progressive pagination support across large lists.

### Changed
- Centralized HTTP behavior in a shared client with typed errors, a 15-second
  timeout, client-version headers, and global unauthorized-session handling.
- Moved friends, event detail, expenses, carpools, and QR state out of widgets
  into injectable feature controllers.
- Raised enforced Flutter test coverage to 20 percent.
- Localized dates, times, EUR amounts, and timezone errors in French and
  English.

### Fixed
- Aligned Docker build-time application and API origins with the generated
  Content Security Policy and smoke tests.
- Made event status calculations use canonical instants across device
  timezones and daylight saving transitions.
- Preserved share and verification tokens across network failures while
  removing sensitive values immediately from browser URLs.
- Routed push intents and legacy query parameters through the declarative
  navigator.

### Dependencies
- Removed unused UI and permission packages, moved launcher icon tooling to
  development dependencies, and updated Playwright.

## [0.1.3] - 2026-06-24

### Dependencies
- *(deps)* Bump actions/checkout from 6.0.3 to 7.0.0.
- *(deps-dev)* Bump playwright from 1.60.0 to 1.61.0 in the npm-dependencies group.
- *(deps)* Bump nginx from 1.31.1-alpine to 1.31.2-alpine.
- *(deps)* Bump actions/setup-java from 5.2.0 to 5.3.0.
- *(deps)* Bump the pub-dependencies group with 2 updates.

### Fixed
- *(auth)* Request bearer token responses on native clients (#115).

### Internal
- Clear native session fallback on logout (#116).

## [0.1.2] - 2026-06-20

### Added
- Extended web smoke coverage across desktop and mobile viewport sizes.

### Fixed
- Hardened frontend API error parsing for malformed or unexpected response
  bodies.

## [0.1.1] - 2026-06-17

### Added
- Added realtime reconnect backoff for more resilient live updates.
- Added frontend coverage reporting to CI.

### Changed
- Switched frontend API URL construction to the shared URI builder.
- Improved frontend maintenance checks and CI coverage paths.
- Updated frontend dependencies, CI actions, and Flutter notification packages.

### Fixed
- Fixed Firebase Messaging handling on unsupported browsers.
- Fixed Firebase environment documentation.
- Logged ignored logout cleanup errors for better diagnostics.

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
