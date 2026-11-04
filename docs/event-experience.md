# Event experience

## Listing and compatibility

The event list defaults to upcoming and ongoing events. Other exclusive views
are pending invitations, owned events (including past events), and past events.
Search is a case-insensitive literal substring of the name, evaluated server-side
before pagination. Search and view are retained in the URL. The frontend requests
50-item pages sorted by start time, descending for past events.

`GET /events` accepts optional `q`, `view`, and `sort`. `view=all` supports the
empty-account check. New queries use versioned chronological cursors bound to
normalized criteria. Calls without these parameters keep the historical behavior
and numeric cursors. Responses remain arrays with `X-Next-Cursor`. Authorization
conditions are unchanged. No database migration is required.

Refreshes rebuild the previously loaded volume. Failed refreshes retain cards;
failed invitation reads retain known statuses and counters. Generation checks
reject stale pagination and search responses.

## Navigation and module access

The main destinations are Events, Friends and Profile. Event creation is the
primary action on the event list. On compact screens it sits at the bottom end
with space reserved below the list. On wide screens it sits in the search toolbar.
Keep search, filters and the secondary trash menu available without repeating the
application or destination title. Friend-request notifications open the requests view.

Module routes support direct links, reload, Back and resuming the destination
after sign-in without retaining sensitive token URLs. Returning to the list
preserves its search and filter criteria.
Each enabled module has a dedicated page with one title, event context and a
return action. Offer shortcuts only to enabled modules the user can access.
Switching modules replaces the current module in navigation history, so Back
returns to the event overview. A module opened directly can also return to its
event overview.

The [backend event access rules](https://github.com/theopeuchlestrade/fiestaaa_back/blob/main/docs/event-access.md)
define permissions. Wait for server-backed access before showing protected
content or actions. A pending invitation does not grant access. See the
[event data lifecycle](performance/event-navigation.md) for cache, refresh and
invalidation behavior.

After successful deletion or realtime removal, return to the event list. An
editor closing at the same time must leave the list visible. If deletion fails,
keep the editor available for retry.

## Forms and drafts

The forms share layout, validation/focus behavior and change tracking. Essential
fields precede expandable advanced settings and modules; the primary action stays
below the scrollable form. Both forms protect unsaved changes when leaving.
Authentication, password reset and profile fields use shared controls and
localized validation feedback. Creation drafts use a versioned SharedPreferences key
scoped by normalized account email. Drafts contain form fields, never auth tokens.
Writes are serialized, debounced for 500 ms and flushed during supported lifecycle
changes and internal navigation. Browser unload requests native confirmation when
there are unsaved changes; asynchronous saving cannot be guaranteed on forced
termination. Drafts remain on the device after logout and are removed after
successful creation or explicit dismissal. Restored addresses require selection
from current search results. Editing tracks changes without persisting a draft.

## Layout and summary

Navigation switches to a rail at 720 logical pixels. Forms are capped at 760 pixels
and event content at 1200. Cards use content-driven rows and one column when text
is enlarged beyond 150%. Manrope and its OFL license are bundled for offline use.

The personal summary respects enabled modules and participation permissions and
is hidden for finished events. It only links to active unanswered polls; invitation responses are shown once
in their dedicated card. Empty personal actions disappear. Contributions and poll
questions belong to their module pages. Needs and personal brings use separate
views, and restricted modules are not mounted before membership is known.

## Loading, accessibility and external actions

Use the same theme, page margins and Back action for loading, failure and loaded
event pages. Keep the module title when known and give placeholders a localized,
accessible loading label. On a transient refresh failure, retain usable content
and input, show one connection banner and offer retry. Make empty, loading and
error states accessible in both languages and themes at 200% text size.

Use shared cards, buttons, fields and semantic colors. Pair semantic backgrounds
with foregrounds that meet 4.5:1 contrast for normal text in both themes. Let
dialog titles wrap while keeping the close action reachable. Keep provider
sign-in branding recognizable, with accessible tap targets and comparable
prominence. QR tickets retain black-on-white contrast, and scanner controls
remain legible over the camera preview. Keep public HTML aligned with the theme
and preserve legal copy.

Event addresses open a provider picker. Offer Google Maps, Waze and
OpenStreetMap, plus Apple Maps on Apple platforms and the web. Use saved
coordinates when available, or search for the full address. Canceling leaves the
event page open. Launch failures show localized feedback. Playlist and fundraiser
links retain their external destinations.

Friend requests show the sender, date and available actions in that order. Keep
tickets, camera, check-in statistics and scan results visually distinct while
preserving ticket authorization and token handling.

## Validation and release

Automated checks cover list recovery, search generations, pagination, local draft
isolation/serialization, draft restore/discard, address revalidation, failed and
successful creation, edit-exit confirmation, and personal summaries. The visual
matrix covers 360/720/1024/1440 pixels, 100%/200% text, both themes and French/English.
Twelve golden images per platform cover six reference screens. Linux and macOS
references are kept separate because their font rasterization differs; pixel
comparisons remain exact. Use the Flutter version pinned in CI on each platform. Linux references were
reviewed from the test-image artifacts produced by the existing GitHub CI runner;
failed comparisons upload diagnostic images without updating references or
relaxing the comparison. Selected cases check tap-target labels and minimum
Android tap-target sizes.

Run frontend analysis and tests with the CI defines and follow the
[coverage policy](testing/coverage.md). Backend library and event integration tests use the isolated `db-test`
service. Compare the local contracts with:

```sh
node tool/check_backend_contract.mjs --source ../fiestaaa_back/openapi.json
```

Before deploying changes to the event experience, verify create/search/open/respond
in the validation environment,
browser back/reload, and VoiceOver/TalkBack on real devices. Observe existing
error reporting and API metrics, and retain the previous frontend for rollback.
