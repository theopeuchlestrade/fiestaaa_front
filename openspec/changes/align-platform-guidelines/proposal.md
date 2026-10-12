## Why
A platform audit found low-contrast semantic theme pairs, truncated modal headings and provider controls that use app branding instead of provider requirements. Android predictive back should be explicitly configured.

## What Changes
- Correct semantic foregrounds, wrap modal headings and test Apple touch targets.
- Use provider sign-in resources and proportional readable controls.
- Opt in to Android predictive back while preserving form exit guards.
- Record the scope of automated evidence and deferred device checks.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `theme`: semantic contrast and provider presentation exceptions.
- `interface-states`: modal accessibility and platform navigation conventions.

## Impact
Frontend only. No API, authentication protocol, permissions, dependency version or production changes. Bundled Google font/logo resources include provenance and license notices.
