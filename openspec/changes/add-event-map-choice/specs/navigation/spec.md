## ADDED Requirements

### Requirement: Explicit event map choice
Event addresses SHALL offer an explicit provider choice before opening an external map. Google Maps, Waze and OpenStreetMap SHALL be available, with Apple Maps additionally available on Apple platforms and web. Saved coordinates SHALL take precedence; otherwise the original address SHALL be searched. Canceling SHALL launch nothing.

#### Scenario: Android default maps app
- **WHEN** an Android user taps an event address
- **THEN** the provider sheet appears before any external launch even if a default map app exists

#### Scenario: Address without coordinates
- **WHEN** an event has an address but no saved coordinates
- **THEN** the address remains actionable and the selected provider receives the full encoded address

#### Scenario: Failed external launch
- **WHEN** the selected provider cannot be opened
- **THEN** the app shows the localized map error and preserves the event page
