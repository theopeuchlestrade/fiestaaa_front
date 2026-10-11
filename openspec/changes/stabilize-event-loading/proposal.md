## Why
Event routes briefly show a legacy app bar titled Fiestaaa before the themed page appears. Membership loading can also insert an extra app bar. These changes make navigation look unfinished.

## What Changes
- Keep initial loading and errors inside the same themed page layout and inline back navigation.
- Show known module titles immediately and neutral content placeholders while event data loads.
- Keep membership gating inside the module header; do not expose restricted actions or data.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `interface-states`: stable event route loading presentation.

## Impact
Frontend presentation only. No API, caching, dependencies, session changes or deployment.
