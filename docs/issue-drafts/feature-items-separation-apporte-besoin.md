# [FRONT] Separate bring vs need items

## Objective
Visually separate "what I bring" and "what I need" items on the event.

## Context
The current mix makes it hard to distinguish creator needs from participant offers.

## User Journey
- Entry point: event page.
- Main steps: creator adds a need; participant adds what they bring.
- Edge cases: no offer, no need.

## UI / UX
- Impacted screens: event detail, item creation/editing.
- Components to create/modify: two sections or tabs; form with item type.
- States (loading, empty, error, success): distinct empty states.
- Micro-interactions: counter by section.

## Responsive
- Mobile: stacked sections.
- Tablet: stacked sections or accordions.
- Desktop: two columns if space allows.

## Accessibility
- Keyboard navigation: consistent tab order.
- Contrast / readability: visible section titles.

## API / Data
- Endpoints used: items list/create/update with item_kind.
- Data format: item_kind (need|bring).
- Cache / pagination: refresh sections after action.

## Analytics / Tracking (if needed)
- Events: item_create_need, item_create_bring.
- Props: event_id, item_id.

## Tests
- Unit tests: section rendering with item_kind.
- Integration: item creation in the correct section.
- E2E (if applicable): creator vs participant flow.

## Definition of Done
- [ ] UX matches the specs
- [ ] Responsive behavior validated
- [ ] Edge states handled
- [ ] Tests pass
- [ ] Docs updated (if needed)

## Notes / Risks
Clarify wording between "bring" and "need".
