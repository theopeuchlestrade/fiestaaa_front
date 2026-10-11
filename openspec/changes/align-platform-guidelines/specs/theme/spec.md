## ADDED Requirements

### Requirement: Platform-readable semantic theme
Semantic foreground/background pairs SHALL meet at least 4.5:1 for normal-size text in both themes. Provider sign-in controls SHALL use the provider's approved visual resources and text, retaining accessible target sizes and equivalent prominence.

#### Scenario: Semantic color override
- **WHEN** a semantic background is overridden by the custom theme
- **THEN** its foreground is also selected and validated for normal-text contrast

#### Scenario: Provider login
- **WHEN** Google or Apple sign-in is offered
- **THEN** the provider artwork and colors remain recognizable and controls stay readable at enlarged text sizes
