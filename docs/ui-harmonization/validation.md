# Harmonization validation

## Completed locally

- Strict OpenSpec: 6 frontend items; 2 backend items.
- actionlint and local Markdown links passed in both repositories.
- Backend OpenAPI compatibility: 63 paths; no contract change.
- Flutter analysis, formatting and diff checks passed after final presentation changes.
- Initial full regression suite: 361 passed; 46.60% line coverage (6343/13612), above the unchanged 22% floor.
- Expanded visual matrix: 576 cases passed, covering 18 screens at four widths, both themes/languages and 100%/200% text.
- Twelve macOS references reviewed: six screens, mobile light English and desktop dark French. Selected reference cases pass text contrast, named tap targets and Android target-size guidelines.
- Direct module links resume after authentication for all five modules (6 route tests).
- Pending invitations and disabled modules do not request protected item data; accepted participant view switching and retained content after failed refresh pass (5 tests).
- All tests use synthetic accounts and isolated fake APIs. No production mutation occurred.

- Final local regression suite: 755 passed; 46.51% line coverage (6369/13694).

## In progress
- Frontend CI, including Android/iOS compilation and exact Linux visual comparison.
- Linux reference update from actual CI-produced test images; never treat copied macOS seed references as validated Linux output.

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
