# Add an event to a calendar

The date/time card on the event detail page opens a calendar picker, using the
same card treatment and bottom-sheet interaction as the postal address.

- Google Calendar opens a prefilled draft, which the user must save.
- iPhone/iPad on iOS 17+: Apple Calendar opens the system EventKitUI editor.
- Android: Device calendar opens the installed calendar editor using ACTION_INSERT.
- Export an .ics file is available everywhere for Proton and other calendars.
  Web clients download the file; native clients use the system share sheet.
- iOS 15/16, Web and desktop offer Google Calendar and the universal export only.

The mobile bridges do not request calendar read/write permissions. iOS uses
EventKitUI without accessing the existing event store; Android delegates creation
to another app. iOS reports saved/cancelled; Android only reports that it opened
the editor, never that an event was saved. Cancellation is silent. An unavailable
editor offers an ICS export. No calendar account connection is required.

This is a one-time snapshot, not a calendar subscription. Exporting does not
create a public event link, send invitations, or modify the Fiestaaa event.
There is no new dependency or backend API. Native bridge messages use
`fiestaaa/calendar` with `isSupported` and `openEditor`; event fields are title,
description, location, UTC epoch milliseconds for start/end, and the IANA zone.
Outcomes are opened, saved, cancelled or unavailable.

## Time and file handling

Use the canonical start instant if supplied; otherwise resolve the event's local
start time in its IANA time zone. An explicit end uses its canonical instant if
available, otherwise its local time in the same zone. Without an explicit end,
propose one hour after the start, ignoring lifecycle end defaults. Invalid ranges
or unknown time zones that prevent conversion produce a retryable error.

Both export formats carry the title, description, address and UTC start/end.
ICS files use a stable event UID, CRLF line endings, escaped text, and UTF-8-safe
line folding at 75 octets. No credentials or invitation tokens are exported.
Google/native launch failures offer an ICS export; export failures offer retry.
Dismissing the picker or the native share sheet does not report success or error.

## Validation — 15 October 2026

- Automated Flutter tests cover canonical dates, default duration, explicit and
  multiday ends, another time zone, both daylight saving transitions, reserved
  characters, Unicode folding, provider selection, dismissal, recovery,
  keyboard activation, accessible labels, and French/English strings.
- A detail-page regression test opens the calendar picker and then the existing
  map picker on simulated iOS, verifying its existing providers remain available.
- Rebased the calendar-only change on current main: 30 focused unit/widget
  tests pass, including the existing event deletion and map regressions.
- Static analysis of the entire application passes.
- All 32 macOS detail layout/accessibility variants pass; the two affected
  macOS golden references were regenerated and visually inspected.
- All 32 Linux detail layout/accessibility variants also pass using Flutter
  3.44.0 in an isolated container; the two affected Linux references were updated.
- The complete application builds successfully for Web.
- Chromium, mobile viewport 390 × 844: visually inspected the French picker;
  downloaded `fiestaaa-42.ics` through the actual Web export and verified its
  name, UTC start/end and escaped title. Verified Google draft URL parameters
  and new-tab handoff with the external request intercepted.

## Native editor follow-up

- 44 focused Flutter tests pass, covering native support/version capability,
  exact bridge payloads, outcomes, absent bridges, errors, platform-specific
  choices and ICS recovery, plus existing time and map regressions.
- Full analysis and Web release compilation pass. The Chrome browser guard
  passes and is included in the existing browser CI step.
- Android debug compilation passes using a temporary ignored Firebase test config.
- The Swift editor implementation typechecks against the iOS SDK with a minimum
  deployment target of iOS 15.
- iOS 27 iPhone simulator: the native editor opened successfully with the exact
  synthetic title, Paris address, description and 31 October 2026 20:30–21:30
  time range, with no calendar-access prompt. Save/cancel callbacks are covered
  by bridge tests; actual UI save/cancel remains to be exercised.
- Android API 35 emulator: ACTION_INSERT handed off to Google Calendar with event
  extras. Its account setup prevented completing a save in this account-free
  environment; the app does not report a save on handoff.

The existing iOS Podfile.lock pins Firebase 12.13.0 while the current Dart plugin
requires 12.19.0. The simulator smoke build used a temporary local pod resolution
and ARM64-only Xcode build (the generic Flutter multi-architecture build also
failed in the local toolchain). The original lock and project settings are
preserved in the PR; no native dependency upgrade is included.

Still requiring device/account validation:

- Save a draft in Google Calendar, then confirm its times and text.
- Import the file in Apple Calendar and Proton Calendar.
- Share the file on physical iOS/Android devices, including iPad placement.
- Verify native editor save/cancel on physical iPhone/iPad and Android.

Physical-device flows and external account imports were not exercised here.

## Interface simplification

The schedule itself and the external-action icon remain clickable. The visible
add-to-calendar prompt, picker heading, confirmation explanation and ICS subtitle
are removed. A nonvisual action label is retained for screen readers.

The schedule, address and description rows use the standard ListTile layout,
with matching leading icon placement, title/subtitle typography and spacing.
The calendar and address actions also share the same trailing icon placement.
