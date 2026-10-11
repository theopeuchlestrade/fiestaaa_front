## ADDED Requirements

### Requirement: Content-first event home
The event home SHALL omit a repeated application or destination heading. Search, filters and the secondary trash menu SHALL remain available. Creation SHALL occupy one consistent primary location: a bottom-end extended action on compact layouts with reserved list padding, and the search toolbar on wide layouts.

#### Scenario: Compact event list
- **WHEN** the available width is below 720 pixels
- **THEN** creation remains reachable above the main navigation and does not obscure the final event card

#### Scenario: Wide event list
- **WHEN** the available width is at least 720 pixels
- **THEN** creation sits beside search without a duplicate page heading
