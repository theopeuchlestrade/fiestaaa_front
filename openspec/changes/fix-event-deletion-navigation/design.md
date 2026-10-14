# Design

The realtime deletion and HTTP completion can race while a MaterialPageRoute editor is departing. `mounted` alone is insufficient during its transition. The editor checks its route is current after completing the form session and waiting for the frame, before returning its deleted result.

Event removal uses a shared departure method: stop realtime, notify observers, show feedback, then explicitly select `/events` when GoRouter exists. Standalone Navigator callers keep their existing one-pop fallback. Routed observers may already request the same destination; no imperative pop is issued afterward, so the home route is never accidentally removed.

Tests cover direct and pushed event entry, HTTP-only completion, realtime-before-HTTP during a transition, failed deletion/retry and standalone Navigator use. Backend permission and soft-deletion rules remain authoritative and unchanged.

## Physical validation

On 14 October 2026, the owner confirmed deletion of the dedicated fictional event in the separate iPhone QA app 0.8.0+9011 returns directly to the event list without a black screen. The app used the isolated local API. This is a physical iPhone result, separate from the 1,093 passing Dart VM tests. No production deletion, TestFlight distribution, Android physical deletion retest or release is claimed.
