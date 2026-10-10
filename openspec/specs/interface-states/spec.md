# Interface States

## Purpose
Define the accepted presentation contract for Fiestaaa.

## Requirements

### Requirement: Readable retained content
Every screen SHALL preserve useful loaded content after a refresh error, expose retry and back, use a single connection banner, and provide accessible empty, loading and error states. Text and actions SHALL remain available at 200% scale, both themes and both supported languages.

#### Scenario: Refresh failure
- **WHEN** a loaded module loses network access
- **THEN** existing content remains visible and the user can retry or return
