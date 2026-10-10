# Event Modules

## Purpose
Define the accepted presentation contract for Fiestaaa.

## Requirements

### Requirement: Module presentation
Enabled modules SHALL have dedicated pages with one title, useful summary, content and primary action. Needs and personal brings SHALL have separate views. Backend openspec/specs/event-access/spec.md is authoritative for roles; the UI SHALL NOT redefine those permissions. Playlist and fundraiser links SHALL retain external destinations.

#### Scenario: Waiting invitation
- **WHEN** a waiting guest opens a protected module route
- **THEN** restricted content is not mounted and an invitation response remains possible from the overview

### Requirement: Event context and sibling navigation
Modules SHALL show one title, event-name context, a return action and permitted enabled sibling destinations. Switching siblings SHALL replace the current module so returning reaches the event rather than a history of sibling pages. Direct links SHALL fall back to their event overview. Existing backend event-access specifications remain authoritative.

#### Scenario: Switch and return
- **WHEN** an accepted participant opens needs from an event and switches to polls
- **THEN** Back returns to that event overview and no disabled or unauthorized destination is offered

#### Scenario: Pending invitation
- **WHEN** a waiting participant opens a protected module
- **THEN** restricted content is not mounted and sibling navigation is not offered
