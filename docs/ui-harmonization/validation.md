# Harmonization validation

## Completed locally

- Strict OpenSpec: 6 frontend items; 2 backend items.
- actionlint and local Markdown links passed in both repositories.
- Backend OpenAPI compatibility: 63 paths; no contract change.
- Flutter analysis, formatting and diff checks passed after final presentation changes.
- Initial full regression suite: 361 passed; 41.85% line coverage (5688/13591), above the unchanged 22% floor.
- Expanded visual matrix: 576 cases passed, covering 18 screens at four widths, both themes/languages and 100%/200% text.
- Twelve macOS references reviewed: six screens, mobile light English and desktop dark French. Selected reference cases pass text contrast, named tap targets and Android target-size guidelines.
- Direct module links resume after authentication for all five modules (6 route tests).
- Pending invitations and disabled modules do not request protected item data; accepted participant view switching and retained content after failed refresh pass (4 tests).
- All tests use synthetic accounts and isolated fake APIs. No production mutation occurred.

- Final full regression suite: 754 passed.

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
