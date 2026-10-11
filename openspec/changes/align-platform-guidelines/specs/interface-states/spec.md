## ADDED Requirements

### Requirement: Platform navigation and modal readability
The app SHALL retain system-compatible back transitions and form exit protection. Shared modal headings SHALL wrap at enlarged text sizes while close controls remain reachable. Platform-specific gesture validation SHALL be recorded separately from widget compilation and tests.

#### Scenario: Enlarged modal heading
- **WHEN** a modal is opened at 200% text size on a narrow screen
- **THEN** its heading is readable and its close control remains available

#### Scenario: Deferred device verification
- **WHEN** automated checks pass but device gesture or assistive technology tests are postponed
- **THEN** delivery documentation identifies those checks as unverified
