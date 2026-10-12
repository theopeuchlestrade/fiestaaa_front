## Decisions
Use the existing page background, margins and inline BackButton throughout loading, failure and membership gating. Module titles are derived from the route and localized; unknown event names use a neutral placeholder. Static themed blocks and one indeterminate linear indicator communicate loading without decorative shimmer or an artificial delay. Skeleton details are excluded from semantics and one localized loading status is exposed.

Fetching and stale-response generation guards remain unchanged. No event data is cached or passed between sessions; restricted modules still mount only after server-backed membership checks. A direct module entry returns to its event, and an overview entry to the event list. Errors remain retryable and scrollable.

## References
- https://developer.apple.com/design/human-interface-guidelines/loading
- https://m2.material.io/components/progress-indicators

## Validation
Hold API responses pending to inspect the intermediate state. Check both themes/languages, 360/720/1024/1440 widths at 200% text, loading navigation, retry and stale response protection. Native store validation is separate; this change is not yet part of distributed 5028.
