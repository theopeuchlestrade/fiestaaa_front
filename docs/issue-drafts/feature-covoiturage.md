# [FRONT] Carpools by event

## Objective
Add a carpool module to the event page (offer a ride, join a ride).

## Context
Recurring need for organizing trips, especially for student associations.

## User Journey
- Entry point: "Carpool" section in the event.
- Main steps: offer a ride, join/leave, see remaining seats.
- Edge cases: no seats left, ride deleted.

## UI / UX
- Impacted screens: event detail.
- Components to create/modify: ride card, creation form, join/leave button.
- States (loading, empty, error, success): empty state prompts users to offer a ride.
- Micro-interactions: remaining seats counter, confirmation.

## Responsive
- Mobile: stacked cards, full-width button.
- Tablet: 2-column grid.
- Desktop: 3-column grid if space allows.

## Accessibility
- Keyboard navigation: focus on join/leave buttons.
- Contrast / readability: readable seat counter.

## API / Data
- Endpoints used: carpool list, create/update/delete, join/leave.
- Data format: seats_total, seats_taken, driver, origin, depart_at.
- Cache / pagination: refresh list after action.

## Analytics / Tracking (if needed)
- Events: carpool_create, carpool_join, carpool_leave.
- Props: event_id, carpool_id.

## Tests
- Unit tests: card rendering + states.
- Integration: join/leave updates the UI.
- E2E (if applicable): complete carpool flow.

## Definition of Done
- [ ] UX matches the specs
- [ ] Responsive behavior validated
- [ ] Edge states handled
- [ ] Tests pass
- [ ] Docs updated (if needed)

## Notes / Risks
Need to clarify whether passengers are displayed or only the counter.
