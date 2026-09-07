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

## Forms and drafts

The forms share layout, validation/focus behavior and change tracking. Essential
fields precede expandable advanced settings and modules; the primary action stays
below the scrollable form. Creation drafts use a versioned SharedPreferences key
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
is hidden for finished events. It shows pending responses, personal contributions
and active unanswered polls. Unknown data offers a retry. The item summary is
independent of the module's selected filter.

## Validation and release

Automated checks cover list recovery, search generations, pagination, local draft
isolation/serialization, draft restore/discard, address revalidation, failed and
successful creation, edit-exit confirmation, and personal summaries. The visual
matrix covers 360/720/1024/1440 pixels, 100%/200% text, both themes and French/English.
Six golden images per platform cover the three screens. Linux and macOS
references are kept separate because their font rasterization differs; pixel
comparisons remain exact. Generate Linux references with the pinned Flutter CI
image and macOS references with the matching local SDK. Selected cases check tap-target labels
and minimum Android tap-target sizes.

Run frontend analysis/tests with the CI defines and maintain the 22% coverage
floor. Backend library and event integration tests use the isolated `db-test`
service. Compare the local contracts with:

```sh
node tool/check_backend_contract.mjs --source ../fiestaaa_back/openapi.json
```

Release the compatible backend before the new frontend. Remote contract CI only
accepts the new snapshot once the backend contract lands on its configured
reference. Production deployment is separate from these local changes. Before
production, verify create/search/open/respond in the validation environment,
browser back/reload, and VoiceOver/TalkBack on real devices. Observe existing
error reporting and API metrics, and retain the previous frontend for rollback.
