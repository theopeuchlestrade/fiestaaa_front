## Why
Friend requests retain redundant summary cards, and ticket/scanner pages still use the earlier decorative gradients and app bars instead of the shared interface.

## What Changes
- Match requests to the simple friends list, with received/sent headings and explicit response actions.
- Replace the decorative ticket with a focused QR pass and collapsible generation/expiry details.
- Put camera, statistics, controls and scan result into separate scrollable regions under a shared event header.
- Add real Flutter renders for all three views to the portable HTML gallery.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `interface-states`: focused request and check-in presentation.

## Impact
Frontend presentation only. No API or permission change, Wallet integration, production deployment or store submission. Existing invitation roles, QR refresh, one-use scan handling and camera lifecycle remain authoritative.
