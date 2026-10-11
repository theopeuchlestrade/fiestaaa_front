## Context
Android previously launched a geo intent immediately, which can silently use a default app. The event address was disabled without coordinates.

## Decisions
Use an explicit, scrollable, safe-area sheet with existing localized labels and standard icons. HTTPS provider links allow platform handling and provider fallback without enumerating installed apps. Apple Maps is omitted on native Android. Coordinates take precedence over text; preserve the original full address for search fallback. Do not start turn-by-turn navigation automatically. Cancellation performs no external action; errors use the existing translated message.

## References
- [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started)
- [Waze deep links](https://developers.google.com/waze/deeplinks)

## Validation
Test mobile provider selection and address-only taps, URI encoding and valid/invalid pins. Phone launches remain a separate owner check.
