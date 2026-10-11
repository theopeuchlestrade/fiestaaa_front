## Why
The owner accepted the home refinement and approved a second design pass on the other screens and their transitions, with an HTML visual review deliverable.

## What Changes
- Share event context, return and permitted sibling destinations across module headers.
- Simplify event access rows, needs headings, poll groups, expense summaries, carpool hierarchy and friends.
- Make profile editing explicit and group preferences/help as settings rows, separating account deletion.
- Provide an explicit sign-in destination after recovery confirmation.
- Export actual French widget renders for mobile and desktop into a navigable HTML gallery.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `event-modules`: shared context and sibling navigation.

## Impact
Frontend presentation and tests only; existing API and backend role contracts remain authoritative. No production deployment, phone installation, store upload or new end-to-end phone validation.
