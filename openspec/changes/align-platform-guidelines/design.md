## Decisions
Keep the shared custom identity and Flutter platform route defaults. Do not equate Material styling on iOS with rejection or claim App Store certification. Fix measured and documented gaps.

Set explicit onTertiary/onError foregrounds for overridden backgrounds and validate all semantic normal-text pairs at 4.5:1. Modal headings can wrap. Extend existing selected accessibility checks to Apple target dimensions without removing Android/label/contrast checks. Retain reduced motion and system theme/text settings.

Provider presentation is separate from the app theme: bundle official Google Sans Medium v14.000 and approved Google gradient G PNG; use a light Google button in both app themes with readable neutral colors. Use the existing sign_in_with_apple control, enlarging the whole control in proportion to text preferences so its internal fixed layout does not clip at 200%. Submission still disables repeated taps; status is announced separately rather than replacing brand artwork.

Enable Android back callback as documented. Existing PopScope form guards and iOS route transitions remain unchanged. Real predictive back, edge swipe and VoiceOver/TalkBack validation is deferred at the owner's request.

See docs/ui-harmonization/platform-guidelines-audit.md for source links and coverage limits.
