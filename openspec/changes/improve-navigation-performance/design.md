# Design

## Context
Baseline: frontend main `322842b2bd67a8780bd274564723b0987f4b89e5` (0.7.0). EventRoutePage clears event context and fetches it before mounting EventDetailPage. Each mount starts polls, items, invitation and payment-provider loaders. Guest module access waits for fetchMyInvitations, then starts protected loads; needs await contributions before clearing loading. These are code observations, not measured production latencies. Existing stale-response guards, RefreshQueue and realtime handling must be preserved. See proposal.md for motivation and docs/openspec.md for the pinned authoritative backend event-access reference.

## Goals / Non-Goals
**Goals:** make warm navigation network-independent where safe; measure cold waterfalls; keep one source of freshness and access evidence across routes.
**Non-Goals:** persistent offline database, optimistic permission changes, backend endpoint changes, animation redesign, production instrumentation containing user data or new dependencies.

## Decisions
1. Establish a baseline first: profile/release mode, monotonic tap-to-useful-content timestamps, API start/end metadata, cold versus warm flows and frame timings. Debug timings are diagnostic only. Record no tokens, addresses, payloads or personal identifiers. Include Amis/Profile/auth entry in the baseline without promising optimization outside event navigation.
2. Use a shared session-scoped in-memory repository, not widget-local caches or disk persistence. Keys include account/session generation, event, resource and query filters. Proposed bounds: 10 least-recently-used events, 30 seconds of freshness for context/modules, 5 minutes maximum stale retention. Access evidence expires after 30 seconds; protected content waits for revalidation after expiry, even if a snapshot remains. A transient failure may retain already displayed data; it cannot grant entry to a restricted page whose evidence expired. Known logout, deletion, suspension, membership removal and 401/403/404 invalidate immediately. Server enforcement remains unchanged; bounded evidence means remote revocation detection is not instantaneous.
3. Pass known event context through the repository while preserving URL-based direct entry. EventRoutePage renders eligible snapshots first and refreshes stale context. Each module loads only its own data after the shared access gate. Overview loads only data needed for conditional invitation/poll actions and configured external links. Expenses list/summary may run concurrently; needs/contributions may overlap after access, with separate loading states rather than an unnecessary all-or-nothing wait.
4. Deduplicate by resource key, retaining request generation guards. Scope-local invalidation generations discard pre-mutation responses. Successful mutations invalidate dependent resources (including overview summaries); realtime events use the same dependency map. Reconnect refreshes active stale data, not every hidden module. Shared consumers must not cancel requests another consumer still needs.
5. Keep per-view UI state separate from resource state: scroll, draft input, loading/error presentation and navigation history remain owned by their routes. No restricted prefetch for pending invitations. Prefer load-on-demand over speculative prefetch until measurements demonstrate a need; avoid introducing polling as a shortcut.

## Risks / Trade-offs
- Stale balances or seat counts → short freshness, explicit refresh, dependency invalidation and server validation of every mutation; never present snapshots as reservations.
- Cross-account leaks or late responses → generation-scoped keys, immediate clearing and delayed-response regression tests.
- Remote revocation between checks → short-lived access evidence, realtime invalidation and authoritative server responses; no durable authorization cache.
- Memory growth → LRU/age bounds and disposal tests with repeated navigation.
- Misleading benchmarks → fixed fixtures, same device/network/mode, 20 samples per flow; publish cold/warm p50/p95 and raw anonymized measurements. Gate warm eligible-content p95 at 200 ms; report backend/network time separately. Cold target is structural (no redundant waterfall), not a promised internet response time.

## Migration Plan
Implement in reviewable stages: baseline; repository and access lifecycle; routes; module scheduling; regression/performance validation. No migration or deployment is part of this preparation. A later candidate is delivered separately after review. Rollback reverts the frontend change; no server or stored-data rollback is needed.

## Open Questions
Actual p50/p95 network and render costs on iPhone, Pixel and web remain to be measured in the baseline. If the 200 ms warm target is missed, identify render costs before adding prefetch or expanding scope.
