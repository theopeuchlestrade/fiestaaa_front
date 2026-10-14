# Design

The realtime deletion and HTTP completion can race while a MaterialPageRoute editor is departing. `mounted` alone is insufficient during its transition. The editor checks its route is current after completing the form session and waiting for the frame, before returning its deleted result.

Event removal uses a shared departure method: stop realtime, notify observers, show feedback, then explicitly select `/events` when GoRouter exists. Standalone Navigator callers keep their existing one-pop fallback. Routed observers may already request the same destination; no imperative pop is issued afterward, so the home route is never accidentally removed.

Tests cover direct and pushed event entry, HTTP-only completion, realtime-before-HTTP during a transition, failed deletion/retry and standalone Navigator use. Backend permission and soft-deletion rules remain authoritative and unchanged.
