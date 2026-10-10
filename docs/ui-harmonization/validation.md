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

## Current status

All frontend CI jobs passed at application commit 70c256ec1c54f5027eb524d9596b7b8664d8bafd (run 38060020259), including Linux visual/accessibility checks, Android/iOS compilation, web smoke tests, OpenSpec and backend contracts. Native testing is in progress; the confirmed device results below identify exact QA builds and tested flows.

## Required before a beta delivery

- Review exact final commits and actual Linux comparison artifacts.
- Local browser keyboard/focus, real history/back/reload and authenticated return across modules.
- Native iPhone and Pixel installation, Google/Apple/email, notification request destination, QR/camera permissions, avatar, modules, draft/exit, offline recovery and realtime updates against an isolated validation backend.
- VoiceOver and TalkBack checks; confirm no clipped essential action with device text enlargement.
- No compilation result is phone validation. Selected device flows have now been confirmed by the owner, as recorded below; remaining flows and iPhone receiver/accessibility checks still require validation.
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

Local regression after final error localization: 756 tests passed. Credential errors are localized in French and English, provider authorization failures use translated copy, and invitations/create/edit no longer expose raw server strings. The safety explanation has separate spacing from the input and stronger typography after Linux detected a contrast failure. Remote validation subsequently passed at 6b882c9; see the current status for the later carpool fix.

The owner confirmed native needs/contribution and realtime behavior on QA build 9002: the iPhone guest contributed one unit, and both devices displayed 3/6 without refreshing the Pixel creator view. This validates this flow on the isolated API, not store distribution or provider authentication.

The owner confirmed native poll voting and realtime behavior on QA build 9002: the iPhone guest voted “Salade”, received confirmation, and the result appeared automatically on the Pixel creator view.

The owner confirmed the native expense summary (24 EUR, 12 EUR per participant) and return navigation to the event on both phones using QA build 9002.

Native carpool testing exposed a delayed refresh: joining succeeded and the creator eventually saw the update, but the page ignored the existing server events (`carpool_created`, `carpool_updated`, `carpool_deleted`, `carpool_joined`, `carpool_left`). The frontend now refreshes on these events without changing the backend contract. A regression test failed before the fix and also checks unrelated events and other event IDs are ignored. Native retesting remains required.

Native carpool retest passed after the fix: the owner confirmed that leaving and rejoining from iPhone QA 9002 promptly updated available seats on Pixel QA 9004 in both directions without a manual refresh. The iPhone receiver still requires the same corrected build and verification.

The owner confirmed native participant lists, pending invitation display, creator-only invitation actions and back navigation on Pixel QA 9004 and iPhone QA 9002.

The owner confirmed the Pixel QA 9004 edit exit guard: Stay preserves unsaved input and Leave discards it without mutating the event. Persistent drafts apply to creation; editing intentionally uses confirmation instead.

The owner confirmed Pixel QA 9004 creation draft persistence: after entering “Test brouillon”, leaving and reopening creation offered the draft and restored its name. No event was created.

The owner confirmed Pixel QA 9004 offline recovery: the interruption banner appeared while loaded needs remained visible, back navigation stayed usable, and restoring Wi-Fi cleared the banner and restored module use.

The owner confirmed Pixel QA 9004 light/French and dark/English presentation on the event list, overview, needs and expenses: readable text, accessible actions and translated labels. This is a selected native screen check, not the entire visual matrix.

The owner confirmed Pixel QA 9004 at the maximum available device font setting on profile, list, overview and needs: readable content and reachable primary actions without clipping or overflow. The exact native scale multiplier was not measured; automated layout tests separately cover 200%.

The owner confirmed TalkBack on Pixel QA 9004 navigation, overview and needs: meaningful control names, logical reading order and audible 3/6 progress; no essential silent control reported on this selected flow.

The owner confirmed the corrected iPhone receiver on QA 9004: editing the carpool notes on Pixel promptly updated the iPhone without manual refresh. Both native platforms have now received existing carpool mutation events successfully.

VoiceOver testing on iPhone QA 9004 was deferred at the owner’s request. Automated semantic checks and Pixel TalkBack results do not establish VoiceOver validation.

The owner confirmed iPhone QA 9004 dark/English presentation on list, overview, needs and expenses, and enlarged text on profile and needs: readable content and reachable actions without reported clipping. The exact native text multiplier was not measured. VoiceOver remains deferred.

The owner confirmed iPhone QA 9004 offline recovery: retained needs, interruption banner, usable return navigation and recovery after Wi-Fi restoration. Both native platforms passed this selected offline flow.

The owner confirmed pending-invitation access on Pixel QA 9004: event information and response actions were visible, while all reserved modules remained inaccessible. The initial credential attempt failed; copying the validated synthetic credentials succeeded.

The owner confirmed Support, Privacy and Terms on both phones with QA 9004: one title, readable content and working back navigation; Support displays 0.5.0 (9004).

## Home design revision

At the owner's request, end-to-end phone validation stopped and design review resumed. The home now omits the repeated Fiestaaas heading, aligns search/filter controls with the cards, and places one creation action at bottom-end on compact layouts or beside search on wide layouts. List padding reserves space for the compact action; first-use content does not duplicate it. Clear-search appears only for nonempty input.

Local validation: 32 home layout cases passed (four widths, both themes/languages, 100%/200% text), including selected contrast/semantic/tap-target checks; seven list behavior tests passed; analysis and strict OpenSpec passed. Two actual macOS home references were regenerated and visually reviewed. Linux home references and remote verification must be refreshed if this proposal is retained. This revision has not been installed on phones or deployed.

The owner accepted the revised home design. Other page/navigation refinements are recorded as unimplemented proposals in design-review-proposals.md; end-to-end phone tests remain stopped.

## Approved page and navigation revision

The owner approved the remaining design proposals and requested a final HTML visual deliverable. Shared module headers now carry event context, back and enabled/permitted sibling destinations. Sibling selection replaces the module route; a targeted test verifies returning to the original event. Event module accesses use quiet destination rows; overview and item/poll scroll storage are keyed by event.

Needs no longer repeat their selected-view heading. Polls separate open/closed groups and use one translated expiration message; instantaneous vote behavior is retained. Expenses distinguish the current account balance from expandable complete splits and participant details. Carpools prioritize origin/departure, remove duplicate proposal headings and preserve join/leave/manage actions. Friends use search above both sections and filter requests without changing the pending badge total. Profile identity editing is explicit; preferences/help use named rows; account management is separate and closes before logout after deletion. Recovery confirmation links to the existing /auth route. Legal text and QR/camera functional exceptions remain unchanged.

The standalone preview.html embeds 36 actual French widget renders across 18 screens (360px light / 1440px dark), with mobile/desktop/compare controls, enlargement and links between related pages. Filled synthetic poll/expense/friend/participant/carpool data now exercise populated layouts. Layout checks caught and corrected poll overflow, friend/map/notes tap sizes and avatar/address contrast.

Local validation: 758 regression tests passed, including 576 layout cases and the existing selected full-screen accessibility checks. Final analysis and strict OpenSpec passed. The last small changes disable selection of the current module and discard canceled handle input; targeted module navigation was rerun. Remote Linux references must be refreshed against the exact committed revision. End-to-end validation remains stopped at the owner's request; no new phone installation, production change or store delivery occurred. VoiceOver remains deferred.

Run 38064646256 at 82ea0d0 produced eight changed Linux references (home, overview, needs and profile). They were reviewed from actual CI images and copied without weakening pixel comparison. Linux also detected overview destination typography and expense-date contrast failures; both were strengthened. The overview references must be refreshed once more for the typography change; final remote validation is still required. The new profile cancel regression passes locally.

To regenerate the portable gallery after presentation changes: run `flutter test test/features/events/presentation/event_visual_test.dart --update-goldens --dart-define=UI_REVIEW_EXPORT=true`, review the actual renders, then run `python3 tool/export_ui_gallery.py`. Export-only gallery renders do not create extra CI baselines.
