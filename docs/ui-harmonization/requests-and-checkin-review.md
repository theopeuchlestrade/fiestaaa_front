# Requests and check-in redesign

## Presentation
Requests now follow the friends list: simple received/sent headings, one identity/date per row, and explicit accept/decline actions. Empty groups and duplicate summary cards are omitted. Response callbacks, filtering, realtime updates and error/retry behavior are retained.

The ticket uses a focused hierarchy inspired by [Apple Wallet guidance](https://developer.apple.com/design/human-interface-guidelines/wallet/): context above the card, a central black-on-white QR, one countdown/instruction and expandable generation/expiry details. This does not add Wallet integration. QR timers and API contracts are unchanged.

The scanner separates context, statistics, camera controls and scan result. Content scrolls at enlarged text; camera errors stay readable and native back remains available. Existing camera/detection/stop/restart behavior and server-side single-use validation remain intact.

## Review artifacts and evidence
The portable HTML gallery includes `#requests`, `#ticket` and `#scanner`, with actual Flutter renders on mobile/light and desktop/dark. Scanner fixture imagery is illustrative, not camera validation. Ticket fixture QR data is fictitious.

The 96 new cases cover 360/720/1024/1440 widths, FR/EN, light/dark and 100%/200% text. All 96 new cases also pass in an isolated Linux container matching CI. Existing friends and denied-camera/back tests pass. Full macOS regression: 913 tests passed; static analysis passed; strict OpenSpec validated 12 items.

QA9007 device acceptance predates this revision. The revised ticket and scanner still need later native QR refresh/scan/repeat-scan/torch/switch-camera checks. No new phone build, production deployment, merge or store submission is claimed here.
