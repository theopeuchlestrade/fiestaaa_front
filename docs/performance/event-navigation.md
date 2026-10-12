# Event navigation resource lifecycle

## Scope

No API, backend authorization, dependency, version or visual-design change. Event reads share complete decoded resources within the active account. Data remains in memory; logout, account replacement (including cookie sessions with identical tokens) and disposal of the app root clear it.

## Keys and lifetimes

`EventDataStore` holds at most ten event buckets, evicted least-recently-used. Each key includes the active session generation, event ID and resource/query (`context`, `access`, `items:all` or a filtered query, `contributions`, `polls`, `expenses`, `expense-summary`, `participants`, `carpools:<sort>`). Identical concurrent reads share one operation across API instances. Snapshots are fresh for strictly less than 30 seconds and retained for strictly less than five minutes. Monotonic elapsed time prevents system-clock corrections from extending access evidence. Tests inject a clock.

Protected snapshot reuse requires fresh server event context and either matching ownership or a fresh accepted invitation. Pending invitations never hydrate protected modules. A new route with expired evidence waits for the server; evidence is not extended by reading the cache. An already open view retains its rendered data during transient failures. Writes continue to be checked by the backend. HTTP 401 clears the session; 403/404/410 discard event snapshots and signal denied access.

## Scheduling

Warm eligible routes hydrate synchronously before their first frame. Stale overview context refreshes in the background; failure retains the overview and offers retry. Overview loads actionable polls and configured fundraising providers, without needs lists. Needs load items and personal contributions concurrently after access verification. Polls load polls. Expenses load expense list, summary and participants concurrently; useful expenses can appear while summary remains loading. Carpools and participants use their respective complete collections. Hidden modules are not prefetched.

Manual refresh invalidates appropriate resources before loading. Parent/child API ownership and deferred transport closing allow a disposed route to release its client without cancelling another consumer's in-flight response. Stale route generations cannot overwrite current UI.

## Invalidation

Successful writes through `ApiHttpClient` invalidate event data. Event paths target that event; resource-ID paths conservatively invalidate retained events because the API does not expose a local resource-to-event index. Membership and account writes also discard access evidence. An old account's write or unauthorized response cannot invalidate the new session.

Realtime events use the same store: items invalidate all item query variants and contributions (including pending reads); polls invalidate polls; expenses invalidate list/summary; rides invalidate all sort variants; event updates and reconnect invalidate the event; deletion and invitation changes additionally discard access evidence. A shared immutable message is processed once across listeners. First connection does not duplicate bootstrap reads, while reconnect resynchronizes active modules. Hidden snapshots refresh on later entry. No polling is added.

Session and per-resource generations reject late reads after invalidation, eviction or account replacement. Pending reads are removed from the sharing map but not aborted underneath another subscriber.

## Diagnostics and benchmark

`NAVIGATION_DIAGNOSTICS=true` enables local bounded resource timing samples (maximum 1,000); default is disabled. Labels contain no URLs, IDs, payloads or credentials. Resource durations include request/body/decoding where wrapped; transport samples measure response completion. Nothing is uploaded.

`tool/navigation_benchmark.dart` is an independent entry point, never imported by production main. It uses real presentation widgets, a zone-injected mock HTTP client, quiet realtime and only fictional data. Each request delays 80 ms. Twelve flows run twenty times each. It records route-to-current-route-content duration, started/settled requests, per-request timelines and native frame build/raster durations. It waits for the current route's text and a completed frame, excluding outgoing-route text. Settled request counts are taken after an additional 200 ms; cold expenses await only useful list content, not every secondary resource.

Web: `flutter build web --release -t tool/navigation_benchmark.dart --base-href=/candidate/`; serve `build/web` at that loopback path, then `node tool/run_navigation_benchmark.mjs http://127.0.0.1:8094/candidate/ output.json` using Node 22 and installed Chrome. Native: build/run that entry point in profile mode with a QA identifier and `BENCHMARK_LABEL`; JSON is written to app temporary storage. Never reuse production identifiers/signing or API settings for this fixture.

Results and limitations: [navigation-results.md](navigation-results.md). Baseline uses frontend main `322842b2bd67a8780bd274564723b0987f4b89e5` plus behavior-neutral factory/realtime injection and a no-op store adapter; candidate uses this PR. No store-delivered build or real-server performance claim follows from this benchmark.
