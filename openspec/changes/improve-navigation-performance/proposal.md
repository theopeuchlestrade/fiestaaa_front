# Proposal

## Why
Navigation repeatedly waits for event context and module data even when the user just visited that event. The themed loading improvements shipped in 0.7.0 address presentation, but the code still contains avoidable request waterfalls; real device latency has not yet been measured.

## What Changes
- Measure cold entry, warm navigation, back navigation and refresh separately before optimizing.
- Reuse bounded, in-memory, session-scoped event and module snapshots; refresh stale data without replacing useful content with a blocking loader.
- Load only the visible module and necessary overview actions; deduplicate concurrent requests and overlap independent requests after authorization.
- Invalidate snapshots on mutations, relevant realtime messages, membership changes, session replacement and logout.
- Preserve direct links, pending-invitation restrictions, navigation history, offline recovery and accessible loading feedback.

## Capabilities

### New Capabilities
- `event-data-lifecycle`: authorized event/module snapshot reuse, freshness, invalidation, request scheduling and measurable navigation latency.

### Modified Capabilities
None. Existing navigation, interface-states and event-modules requirements remain applicable.

## Impact
Frontend event routes, detail/module loaders, session lifecycle and realtime integration, with regression and performance checks. Backend event-access remains authoritative (see docs/openspec.md); no API changes, migrations, persistent private cache, new dependency, session-expiry change or production/store delivery is included. The first implementation focuses on event navigation; Amis/Profile/authentication receive baseline measurements, with optimization added only through a reviewed scope extension if evidence warrants it.
