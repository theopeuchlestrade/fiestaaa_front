# Tasks

## 1. Baseline and measurement
- [x] 1.1 Add opt-in local timing/request-count diagnostics without payloads or credentials; verify synthetic request timing tests and disabled-by-default behavior.
- [x] 1.2 Record 20 samples for cold event entry, module entry, sibling switch, back and warm revisit on a fixed isolated fixture; deliver baseline p50/p95, request waterfalls, mode/device/network details and raw anonymized results. Include exploratory Amis/Profile/auth entry timings.

## 2. Session-scoped resource lifecycle
- [x] 2.1 Add bounded snapshot storage with query/session keys, freshness and LRU eviction; verify fake-clock expiry, capacity and no persistent private writes.
- [x] 2.2 Add shared server-backed access evidence and logout/session invalidation; verify pending invitation, expired evidence, 401/403/404, account switch and late-response tests.
- [x] 2.3 Deduplicate in-flight resource loads and guard invalidated generations; verify concurrent consumers issue one request and older responses never replace post-mutation state. Document lifecycle/key semantics alongside tests.

## 3. Route and module scheduling
- [x] 3.1 Reuse eligible event context in EventRoutePage with background refresh; verify cold/direct links, warm first frame, retry, back and refresh failure widget tests.
- [x] 3.2 Replace unconditional EventDetailPage initialization with overview/module-specific loading; verify request spies show no needs/polls/providers fetch on expenses or carpools entry and pending guests never load protected resources.
- [x] 3.3 Parallelize independent authorized needs/contributions and expense resources while retaining separate useful/error states; verify delayed-response tests demonstrate overlap and no hidden all-data barrier. Document expected request graphs.

## 4. Freshness and realtime integration
- [x] 4.1 Add a dependency map for successful contributions, votes, expenses, rides and invitation changes; verify immediate revisit, overview freshness and mutation-versus-fetch races.
- [x] 4.2 Route realtime changes/reconnect through the same invalidation model; verify active-view updates, hidden-view freshness, no polling duplicates and no cancellation of another consumer's request. Document invalidation cases.
- [x] 4.3 Preserve scroll, drafts, one connection banner and return actions through refresh; verify offline/reconnect tests and repeated navigation eviction/disposal tests.

## 5. Integrated acceptance
- [x] 5.1 Run analysis, full regression tests, backend contract and strict OpenSpec CI; record exact successful checks without changing backend permissions or API snapshots.
- [x] 5.2 Compare baseline/candidate on iPhone, Pixel and web in matching profile/release conditions; record 20 samples per selected flow, cold/warm p50/p95, request counts and rendering time. Require eligible warm content p95 <= 200 ms and no unrelated requests or avoidable serial cold stages; explicitly list any untested platform.
- [ ] 5.3 Verify creator, accepted and pending roles, direct links, sibling/back navigation, account replacement, realtime and network recovery on the isolated environment; record light/dark FR/EN and enlarged-text/loading accessibility regressions. Prepare a reviewable PR with evidence and remaining limitations; no production/store delivery.

## Workflow follow-up
- Archive only after implementation and review criteria pass. Any new beta delivery or production deployment is a separate authorized step.

## Evidence and remaining acceptance

See `docs/performance/event-navigation.md` and `docs/performance/navigation-results.md`. Automated regression coverage does not replace a live isolated-server end-to-end run. Final device benchmarks and exact-head CI are recorded separately; unperformed checks remain open.

Implementation CI passed on `b2c77a67d5e56f7d690e045c6771eaf763b4ff46`: https://github.com/theopeuchlestrade/fiestaaa_front/actions/runs/38259385096. The follow-up commit only records validation evidence; task 5.3 remains open.
