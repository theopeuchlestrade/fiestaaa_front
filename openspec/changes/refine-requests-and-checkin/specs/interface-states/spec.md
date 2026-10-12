## ADDED Requirements

### Requirement: Focused requests and check-in pages
The app SHALL display friend requests using a simple identity/date/action hierarchy and SHALL separate ticket, camera, statistics and scan-result content while retaining existing authorization and token behavior.

#### Scenario: Received and sent requests
- **WHEN** pending requests exist
- **THEN** received requests expose accept/decline actions and sent requests expose pending status, without a duplicate summary panel

#### Scenario: Ticket in dark mode
- **WHEN** an invited participant opens the ticket in either theme
- **THEN** its QR remains black on white with a quiet zone, and generation/expiry details remain available without repeating the page title

#### Scenario: Camera error and result
- **WHEN** camera access is denied or a scan completes
- **THEN** a readable scrollable state is shown, back remains available, and scan-next preserves the existing scanner lifecycle

#### Scenario: Portable preview
- **WHEN** a scanner render is reviewed in HTML
- **THEN** the gallery explicitly identifies its camera area as an illustration and does not claim device QR validation
