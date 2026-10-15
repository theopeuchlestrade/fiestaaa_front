## ADDED Requirements

### Requirement: Event removal preserves a usable destination

After successful deletion or a realtime removal, the application SHALL return to the event list without popping a different route when an editor transition is already in progress. A failed delete SHALL keep the editor available for retry.

#### Scenario: HTTP deletion completes normally
- **WHEN** a creator confirms deletion from an event opened directly or from the list
- **THEN** the event list is visible and the editor is closed

#### Scenario: Realtime deletion precedes HTTP completion
- **WHEN** the realtime deletion starts removing the editor before its HTTP response completes
- **THEN** the late response does not pop the list or trigger a navigator assertion

#### Scenario: Deletion fails
- **WHEN** the server rejects deletion
- **THEN** the editor remains usable and the creator can retry
