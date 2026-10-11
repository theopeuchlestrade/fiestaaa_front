# Apple and Android interface audit — 12 October 2026

## Scope and conclusion
The shared interface has a good foundation, but there was no basis for declaring complete HIG/Material compliance. This audit examines source behavior and synthetic widget fixtures, not App Store certification. The owner requested platform guideline alignment and deferred new phone tests.

Preserve Manrope and violet/cyan for the app. Provider sign-in controls are exceptions with their own branding. HIG/Material do not require making every custom app look identical to system Settings, nor does using Flutter Material on iOS alone establish a violation. Native gestures and assistive technology still need device verification.

## Evidence matrix

| Area | Evidence and finding | Action / status |
| --- | --- | --- |
| Main destinations | Three persistent labeled destinations, explicit event module routes, contextual back, pending invitation restrictions | Retained; route/permission regression tests |
| Loading / errors | Legacy generic app bar replaced the final header during event fetch, and membership gating inserted an extra bar | Corrected in the coordinated loading change; localized status, neutral placeholders, retry and back |
| Touch targets | Theme uses padded targets and standard density; selected rendered states pass Android 48 dp target checks | Add Apple 44 pt checks to the same rendered states; custom dialogs remain separately checked |
| Typography / adaptation | 18 screen fixtures cover four widths, light/dark, FR/EN, 100%/200% text (576 cases) | Retained; no disabled text scaling in general UI |
| Semantic colors | Overriding tertiary/error background colors without matching foregrounds left tertiary contrast at 3.29:1 light / 4.00:1 dark | Correct explicit foregrounds; all eight semantic normal-text pairs meet 4.5:1 in both themes |
| Modal headings | Shared input modal title was limited to one ellipsized line | Allow wrapping; test a long heading at 360 px and 200% text with close control available |
| Input boundaries / navigation labels | Pale input outlines and muted unselected navigation labels need stronger contrast beyond text-only fixture checks | Strengthen theme outline and unselected label colors; test control-boundary contrast at 3:1 |
| Public navigation targets | Public HTML navigation used 44 px height | Raise to 48 px minimum in the generator and regenerate without changing legal text |
| Motion | Shared entrance and duration helpers respect reduced animation / accessible navigation | Retained; existing regression tests |
| Insets / keyboard | Shared page SafeArea, scrollable forms and modal keyboard insets; QR overlay reserves safe area | Retained; fixture tests cannot establish behavior with every physical keyboard/cutout |
| Android back | SDK provides predictive transitions and forms use PopScope, but main manifest had no explicit opt-in | Add documented `enableOnBackInvokedCallback=true`; device gesture verification deferred |
| iOS back | Flutter platform transitions use Cupertino behavior; unsaved form protection remains | Device edge-swipe/VoiceOver escape verification deferred |
| Provider controls | Google control used Manrope/app colors and a hand-painted old logo; Apple used a custom Material icon control | Google: official gradient asset, bundled Google Sans Medium, prescribed light colors; Apple: existing provider control with black/white styles and proportional enlargement |
| Screen reader semantics | Existing labels, role-specific controls, needs progress semantics and localized notices | Automated label checks retained; new VoiceOver/TalkBack tests deferred by owner |
| Destructive actions | Account/event deletion and removals retain explicit confirmation; no new destructive operation | Retained; functional tests |
| Camera / QR | Dedicated camera state and black-on-white ticket remain intentional exceptions | Native camera/permission/reader checks deferred |
| Public documents | Shared HTML identity and unchanged legal text retained | This is a design audit, not legal/store-data declaration approval |

## Screen inventory
Fixture coverage: event list, creation, modification, overview, needs, polls, expenses, carpools, participants, friends, profile, authentication, recovery, safety, privacy, terms, support and deletion. Source additionally reviewed: invitation list, trash, ticket/scanner, shared modal shell, form exit guards, route loading, theme, motion and main navigation. Not every action dialog has a separate screenshot; do not interpret the 576 cases as exhaustive screen-reader or platform certification.

## Sources
- Apple buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- Apple accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple loading: https://developer.apple.com/design/human-interface-guidelines/loading
- Apple sign-in: https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
- Android accessibility (contrast, targets, labels): https://developer.android.com/guide/topics/ui/accessibility/apps
- Android predictive back: https://developer.android.com/design/ui/mobile/guides/patterns/predictive-back
- Flutter predictive back configuration: https://docs.flutter.dev/platform-integration/android/predictive-back
- Google sign-in branding (July 2026 revision): https://developers.google.com/identity/branding-guidelines

## Delivery limits
No merge, production deployment or store submission is part of this audit. Distributed 0.6.0 (5028) is unchanged. Review the new candidate's sign-in screen and replay selected gestures/assistive technology checks before claiming native validation. Audit findings concern design/behavior; store acceptance and legal compliance are separate.

## Verification record

The pre-change 576 fixture variants passed existing checks, which did not detect all color-pair or platform-specific states. New targeted tests reproduce low tertiary contrast before correction; after correction all eight semantic normal-text pairs pass in both themes, plus input-boundary contrast at 3:1. Eleven targeted theme/modal/auth tests pass, including an iOS-targeted sign-in screen at 200% text.

All 576 updated Linux render cases pass layout and the selected label/contrast/Android/Apple target checks using the existing Flutter 3.44.0 image in an isolated copy. Updated reference pixels are generated from these real tests rather than copied from macOS. The macOS gallery uses actual renders with the bundled fonts. Source text of public documents was compared before/after stripping CSS and is unchanged.

Full local regression: **817 tests passed**; analysis reported no issues; strict OpenSpec validated 11 items. Cold-cache logo decoding is explicitly awaited and asserted before auth references are captured. Remote CI is pending for the updated PR. Phone tests remain deferred.
