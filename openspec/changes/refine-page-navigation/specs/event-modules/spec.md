## ADDED Requirements

### Requirement: Event context and sibling navigation
Modules SHALL show one title, event-name context, a return action and permitted enabled sibling destinations. Switching siblings SHALL replace the current module so returning reaches the event rather than a history of sibling pages. Direct links SHALL fall back to their event overview. Existing backend event-access specifications remain authoritative.

#### Scenario: Switch and return
- **WHEN** an accepted participant opens needs from an event and switches to polls
- **THEN** Back returns to that event overview and no disabled or unauthorized destination is offered

#### Scenario: Pending invitation
- **WHEN** a waiting participant opens a protected module
- **THEN** restricted content is not mounted and sibling navigation is not offered
