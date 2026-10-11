## ADDED Requirements

### Requirement: Stable event loading shell
Initial event route loading and failure SHALL use the same theme, page margins and inline back navigation as loaded event pages. Known module titles SHALL remain visible during event and membership loading. Unknown content SHALL use neutral placeholders with a localized accessible loading status. Restricted module content and actions SHALL remain unavailable before membership is verified.

#### Scenario: Deferred event response
- **WHEN** an event or module route is entered and the event response is pending
- **THEN** the themed layout and back action appear immediately without a generic Fiestaaa app bar

#### Scenario: Deferred membership response
- **WHEN** the event is loaded but membership is still pending
- **THEN** the module title and inline navigation remain visible without mounting restricted controls

#### Scenario: Initial load failure
- **WHEN** event loading fails
- **THEN** the same page layout offers localized retry and a usable back action
