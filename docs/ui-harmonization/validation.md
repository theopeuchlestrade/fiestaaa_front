# Harmonization validation

## Completed locally

- Strict OpenSpec: 6 frontend items; 2 backend items.
- actionlint and local Markdown links passed in both repositories.
- Backend OpenAPI compatibility: 63 paths; no contract change.
- Flutter analysis, formatting and diff checks passed after final presentation changes.
- Initial full regression suite: 361 passed; 46.60% line coverage (6343/13612), above the unchanged 22% floor.
- Expanded visual matrix: 576 cases passed, covering 18 screens at four widths, both themes/languages and 100%/200% text.
- Twelve macOS references reviewed: six screens, mobile light English and desktop dark French. All 18 screens pass text contrast, named tap targets and Android target-size guidelines in the mobile light English and desktop dark French accessibility cases.
- Direct module links resume after authentication for all five modules (6 route tests).
- Pending invitations and disabled modules do not request protected item data; accepted participant view switching and retained content after failed refresh pass (5 tests).
- All tests use synthetic accounts and isolated fake APIs. No production mutation occurred.

- Final local regression suite: 755 passed; 46.51% line coverage (6369/13694).

## In progress
- Frontend CI, including Android/iOS compilation and exact Linux visual comparison.
- Final browser fixes and corresponding Linux reference refresh.

## Required before a beta delivery

- Review exact final commits and actual Linux comparison artifacts.
- Local browser keyboard/focus, real history/back/reload and authenticated return across modules.
- Native iPhone and Pixel installation, Google/Apple/email, notification request destination, QR/camera permissions, avatar, modules, draft/exit, offline recovery and realtime updates against an isolated validation backend.
- VoiceOver and TalkBack checks; confirm no clipped essential action with device text enlargement.
- No compilation result is phone validation. The user confirmed both devices will be available; no new device validation has been performed yet.
- Create the beta candidate as a separate delivery after these checks. No release tag, store upload, deployment or publication is authorized by this preparation.

## Dependency limitation

OpenSpec 1.14.1's development-only braces advisory has no upstream patched version as of this review. See ../openspec.md for the exact root advisory and limited execution context. The dependency audit is not clean.

## First remote CI observation

Backend PR 213 is green, including Rust tests, coverage and container scan. Frontend run 38038353418 compiled Android/iOS and the web container successfully, but failed exact Linux comparisons and detected several contrast cases that were not flagged by macOS. Link typography/contrast and the secondary event title were strengthened; support navigation now uses a distinct label. The comparison still fails on mismatching pixels and produces artifacts even when an accessibility check fails. Final remote CI is still required.

## Linux reference provenance

The 12 Linux references were reviewed and replaced with actual test images from GitHub Actions run 38039174003 at commit 9a490735f9a9200cf0d1d3f8a48de18c73adc91f (Flutter 3.44.0). All selected accessibility checks passed in that run; exact pixel comparisons correctly failed against the provisional macOS seeds. The reference update changes no application or test logic. A subsequent green CI run is required to validate these references.

## Browser validation findings

Run 38039468296 passed every CI job, including native compilation and Linux comparisons. Local web testing then identified the hidden Flutter semantics opt-in and unchanged browser URLs after imperative navigation. Web startup now exposes semantics using the official Flutter approach; pushed event/module URLs are reflected because every GoRoute is independently loadable. Route tests cover push/pop URL restoration. The list and navigation label use “Fiestaaas”; icon semantics retain pending counts without repeating the destination name. The resulting final revision still requires CI and browser verification.

The two list references were refreshed from run 38040033077 at commit 8a8983bc17f9ff4da9111d8c9c5b1c2b55946f63 to include the plural destination label. The other ten references matched exactly; accessibility checks and all compilation jobs passed.

## Isolated browser environment

The local API uses backend PR 213 with a new PostgreSQL database on loopback port 55442, Redis on 56382 and API port 18480. Fresh encryption/session keys and three synthetic accounts are stored outside Git. No production database, existing QA database or external messaging credentials are used. Web output is served on loopback port 8089. Browser checks confirmed email sign-in, event/module URLs, module reload and creation of an organizer need. Progress semantics were isolated so web controls remain individually accessible, and the item dialog close action was named. Native devices, provider authentication, delivery of notifications and actual screen reader speech remain unverified for this revision.

The browser contribution flow was verified end to end: a creator added “Boissons sans alcool” (6 units), contributed 2, and saw 2/6 plus “Edit my contribution”. The semantic tree now exposes filters, add/view/contribute/delete separately from the progress indicator. The conditional personal action opened the poll route. The Pixel currently runs Google Play 0.5.0 (5027), so local installation must not overwrite it without a compatible certificate; a separate QA app or a later store delivery is required. Both phones are detected over USB.

Final local validation after expanded accessibility checks: 755 tests passed, including 576 layout cases and 36 full-screen accessibility cases. Xcode on the Mac required all CocoaPods targets to respect the existing iOS 15 minimum; applying that setting produced a successful unsigned QA build and a development-signed QA installation on iPhone. Android QA installed alongside Google Play but its first login hit a local HTTP networking error; QA-specific transport configuration is being corrected, with production transport protections unchanged.

## Native QA progress

The owner confirmed sign-in and event display on iPhone (guest) and Pixel (creator), using separate QA build 9002. Android local HTTP was enabled only for the Mac LAN address in the disposable QA source. Store apps remain installed. Native contribution/realtime validation is in progress. Node 22.23.3 is installed through NVM; strict OpenSpec passes for both repositories.

Local regression after final error localization: 756 tests passed. Credential errors are localized in French and English, provider authorization failures use translated copy, and invitations/create/edit no longer expose raw server strings. The safety explanation has separate spacing from the input and stronger typography after Linux detected a contrast failure. Final remote validation remains required.

The owner confirmed native needs/contribution and realtime behavior on QA build 9002: the iPhone guest contributed one unit, and both devices displayed 3/6 without refreshing the Pixel creator view. This validates this flow on the isolated API, not store distribution or provider authentication.

The owner confirmed native poll voting and realtime behavior on QA build 9002: the iPhone guest voted “Salade”, received confirmation, and the result appeared automatically on the Pixel creator view.

The owner confirmed the native expense summary (24 EUR, 12 EUR per participant) and return navigation to the event on both phones using QA build 9002.

Native carpool testing exposed a delayed refresh: joining succeeded and the creator eventually saw the update, but the page ignored the existing server events (`carpool_created`, `carpool_updated`, `carpool_deleted`, `carpool_joined`, `carpool_left`). The frontend now refreshes on these events without changing the backend contract. A regression test failed before the fix and also checks unrelated events and other event IDs are ignored. Native retesting remains required.
