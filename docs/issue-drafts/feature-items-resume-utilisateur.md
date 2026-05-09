# [FRONT] User item summary

## Objective
Display a summary of the items the user should bring on the event page (and profile if available).

## Context
The global item list is long; a personal summary will avoid manual searching.

## User Journey
- Entry point: event page ("My items" section).
- Main steps: view the list, open an item if needed.
- Edge cases: no item, user is not a participant.

## UI / UX
- Impacted screens: event detail, profile (optional).
- Components to create/modify: "My items" list with status/quantity.
- States (loading, empty, error, success): clear empty state.
- Micro-interactions: "View all items" link.

## Responsive
- Mobile: compact list.
- Tablet: section next to other information.
- Desktop: side panel if possible.

## Accessibility
- Keyboard navigation: list navigation.
- Contrast / readability: readable status.

## API / Data
- Endpoints used: GET /events/{id}/my-items (or my_items in GET /events/{id}).
- Data format: items + quantity + status.
- Cache / pagination: short cache, refresh after update.

## Analytics / Tracking (if needed)
- Events: none.
- Props: none.

## Tests
- Unit tests: empty vs populated list rendering.
- Integration: display with data.
- E2E (if applicable): user sees their items.

## Definition of Done
- [ ] UX matches the specs
- [ ] Responsive behavior validated
- [ ] Edge states handled
- [ ] Tests pass
- [ ] Docs updated (if needed)

## Notes / Risks
Ensure consistency with the global list.
