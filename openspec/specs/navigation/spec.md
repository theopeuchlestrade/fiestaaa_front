# Navigation

## Purpose
Define the accepted presentation contract for Fiestaaa.

## Requirements

### Requirement: Explicit destinations
The main navigation SHALL expose events, friends and profile, with creation on the event list. Module routes SHALL preserve direct access, back, reload, list criteria and authentication continuation. Friend notifications SHALL select requests.

#### Scenario: An authenticated return
- **WHEN** a user signs in after opening /events/42/items
- **THEN** the item destination resumes without claiming an invitation token twice
