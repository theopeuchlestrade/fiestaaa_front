## ADDED Requirements

### Requirement: Shared visual language
All pages SHALL use Manrope and the violet/cyan theme with consistent headers, fields, buttons and semantic statuses. Full content SHALL appear once per page. Legal wording SHALL remain unchanged. QR codes SHALL stay black on white and camera views SHALL remain usable.

#### Scenario: Responsive presentation
- **WHEN** a page is displayed in either language or theme at 360, 720, 1024 or 1440px with 200% text
- **THEN** content and essential actions remain readable without overflow and forms are limited to 760px within a 1200px page

### Requirement: Explicit navigation
The main destinations SHALL be events, friends and profile. Creation SHALL be the primary list action. Event modules SHALL have routes under /events/:eventId for items, polls, expenses, carpools and participants. Old links, list criteria, back/reload and authenticated return SHALL remain functional.

#### Scenario: Friend request notification
- **WHEN** a friend request notification is opened
- **THEN** the friends requests section is selected independently of numeric tab positions

#### Scenario: Direct module link
- **WHEN** a permitted user authenticates after opening a module route
- **THEN** that route resumes and server rules from the backend openspec/specs/event-access/spec.md (fiestaaa_back repository) still apply

### Requirement: Conditional overview actions
Event overviews SHALL contain practical information and enabled module links without reproducing module lists. The personal action area SHALL disappear if no action is required and SHALL NOT list contributions or poll questions.

#### Scenario: Participant with an unanswered poll
- **WHEN** an accepted participant has an active unanswered poll
- **THEN** the overview provides a poll action and the question and votes remain on the polls page

### Requirement: Retained state
Refresh failures SHALL retain loaded content and back navigation. Create and edit SHALL share validation and preserve draft and exit protection. Needs SHALL remain distinct from personal brings.

#### Scenario: Network interruption
- **WHEN** refreshing a loaded event fails
- **THEN** its existing content remains visible with one connection notice and a working back action
