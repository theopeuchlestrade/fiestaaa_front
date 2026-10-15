# Add an event to a calendar

The date/time card on the event detail page opens a calendar picker, using the
same card treatment and bottom-sheet interaction as the postal address.

- Google Calendar opens a prefilled draft, which the user must save.
- Apple Calendar and other calendars receive an iCalendar (`.ics`) file.
- Proton Calendar receives the same file, with instructions to import it using
  Settings → All settings → Import/export on the Proton Calendar website.
- Web clients download the file; native clients use the system share sheet.
  Available import targets depend on the operating system and installed apps.

This is a one-time snapshot, not a calendar subscription. Exporting does not
create a public event link, send invitations, or modify the Fiestaaa event.
There is no new dependency or backend API.

## Time and file handling

Use the canonical start instant if supplied; otherwise resolve the event's local
start time in its IANA time zone. An explicit end uses its canonical instant if
available, otherwise its local time in the same zone. Without an explicit end,
propose one hour after the start, ignoring lifecycle end defaults. Invalid ranges
or unknown time zones that prevent conversion produce a retryable error.

Both export formats carry the title, description, address and UTC start/end.
ICS files use a stable event UID, CRLF line endings, escaped text, and UTF-8-safe
line folding at 75 octets. No credentials or invitation tokens are exported.
Google launch failures offer an ICS export; export failures offer retry.
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

Still requiring device/account validation:

- Save a draft in Google Calendar, then confirm its times and text.
- Import the file in Apple Calendar and Proton Calendar.
- Share the file on physical iOS/Android devices, including cancellation and
  iPad share-sheet placement.

These external imports and native device flows were not exercised here.
