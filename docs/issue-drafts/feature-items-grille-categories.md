# [FRONT] Item grid + categories + quantity summary

## Objective
Display items as a responsive grid with simple categories and a quantity summary.

## Context
The current list is long. A grid + category filter makes it easier to quickly see what people are bringing.

## User Journey
- Entry point: items section on the event page.
- Main steps: switch by category, review quantities.
- Edge cases: no selected category, empty list.

## UI / UX
- Impacted screens: event detail.
- Components to create/modify: item grid, category chips, summary block.
- States (loading, empty, error, success): empty state by category.
- Micro-interactions: reflow animation during filtering.

## Responsive
- Mobile: 2 columns.
- Tablet: 3 columns.
- Desktop: 4+ columns depending on width.

## Accessibility
- Keyboard navigation: navigation across chips and cards.
- Contrast / readability: readable category tags.

## API / Data
- Endpoints used: items list (with category) + summary if available.
- Data format: category, quantity, status.
- Cache / pagination: simple cache, refresh after update.

## Analytics / Tracking (if needed)
- Events: category_filter_click.
- Props: event_id, category.

## Tests
- Unit tests: responsive grid rendering.
- Integration: category filter.
- E2E (if applicable): user filters and sees the summary.

## Definition of Done
- [ ] UX matches the specs
- [ ] Responsive behavior validated
- [ ] Edge states handled
- [ ] Tests pass
- [ ] Docs updated (if needed)

## Notes / Risks
Validate category names (soft drinks/alcohol/savory/sweet/other).
