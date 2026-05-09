# [FRONT] Shared playlist on event

## Objective
Display and allow editing a shared playlist on the event page.

## Context
Participants need a shared music space (Spotify/Apple Music/Deezer).

## User Journey
- Entry point: event page (creator) and event page (participant).
- Main steps: add link, save, open the playlist.
- Edge cases: invalid link, unknown provider, link removal.

## UI / UX
- Impacted screens: event detail, event editing.
- Components to create/modify: URL input, provider select/auto-detect, "Open" button.
- States (loading, empty, error, success): save loading, validation error, empty state.
- Micro-interactions: provider icon, confirmation toast.

## Responsive
- Mobile: stacked fields, full-width button.
- Tablet: 2-column layout if space allows.
- Desktop: aligned link + button.

## Accessibility
- Keyboard navigation: visible labels + focus.
- Contrast / readability: readable error message.

## API / Data
- Endpoints used: GET /events/{id}, PATCH /events/{id}.
- Data format: playlist_url, playlist_provider.
- Cache / pagination: refresh data after save.

## Analytics / Tracking (if needed)
- Events: playlist_open, playlist_save.
- Props: event_id, provider.

## Tests
- Unit tests: URL UI validation.
- Integration: save + display.
- E2E (if applicable): creator adds, participant opens.

## Definition of Done
- [ ] UX matches the specs
- [ ] Responsive behavior validated
- [ ] Edge states handled
- [ ] Tests pass
- [ ] Docs updated (if needed)

## Notes / Risks
Need a clear list of supported providers.
