# Dart VM lines coverage

Commit: `6ddfe2b0da1cba38503e045d8e88ca730ef408b1` · 2026-10-28T16:26:09.432Z

| Measure | Covered / total | Coverage | Enforced / target |
|---|---:|---:|---:|
| Raw collector | 9639/14260 | 67.59% | — |
| Application | 9129/12789 | 71.38% | 70% / 70% |
| authentication-sessions | 958/1157 | 82.80% | 80% / 80% |
| permissions-participation | 886/1104 | 80.25% | 80% / 80% |
| cache-synchronization | 814/985 | 82.64% | 80% / 80% |
| notifications-qr | 622/672 | 92.56% | 80% / 80% |

Patch: **not-requested**.

Result: **passed**.


## Largest uncovered areas

- `lib/src/features/friends/presentation/pages/friends_page.dart`: 430 uncovered collector lines (62.67%)
- `lib/src/features/events/presentation/pages/event_create_page.dart`: 299 uncovered collector lines (59.32%)
- `lib/src/features/events/presentation/pages/event_edit_page.dart`: 299 uncovered collector lines (59.43%)
- `lib/src/features/carpools/presentation/pages/event_carpools_page.dart`: 247 uncovered collector lines (43.35%)
- `lib/src/features/events/presentation/pages/event_expenses_page.dart`: 203 uncovered collector lines (68.18%)
- `lib/src/features/events/presentation/widgets/event_detail_poll_methods.dart`: 190 uncovered collector lines (32.86%)
- `lib/src/app.dart`: 141 uncovered collector lines (64.93%)
- `lib/src/features/home/presentation/pages/home_page.dart`: 113 uncovered collector lines (49.33%)
- `lib/src/features/events/presentation/pages/event_invitations_page.dart`: 111 uncovered collector lines (70.63%)
- `lib/src/features/events/presentation/widgets/event_detail_feature_methods.dart`: 103 uncovered collector lines (0.00%)
- `lib/src/features/profile/presentation/pages/profile_page.dart`: 94 uncovered collector lines (72.11%)
- `lib/src/features/events/presentation/widgets/event_detail_invitation_card.dart`: 91 uncovered collector lines (44.17%)
- `lib/src/features/events/presentation/pages/event_detail_page.dart`: 91 uncovered collector lines (73.31%)
- `lib/src/features/events/presentation/widgets/event_detail_navigation_methods.dart`: 89 uncovered collector lines (27.64%)
- `lib/src/features/carpools/presentation/pages/carpool_create_page.dart`: 83 uncovered collector lines (59.11%)

## Eligible sources absent from measurement

- `lib/main.dart`
- `lib/src/core/pending_token_storage.dart`
- `lib/src/core/platform_http_client_stub.dart`
- `lib/src/core/platform_network_image.dart`
- `lib/src/core/platform_network_image_stub.dart`
- `lib/src/core/platform_web_socket.dart`
- `lib/src/core/platform_web_socket_stub.dart`
- `lib/src/features/auth/data/session_storage.dart`
- `lib/src/features/auth/data/session_storage_stub.dart`
- `lib/src/features/carpools/presentation/carpools_controller.dart`
- `lib/src/features/events/presentation/event_expenses_controller.dart`
- `lib/src/features/events/presentation/event_form_browser_guard.dart`
- `lib/src/features/friends/presentation/friends_controller.dart`
- `lib/src/features/invitations/presentation/pages/my_invitations_page.dart`
- `lib/src/features/profile/presentation/pages/avatar_file_picker.dart`
- `lib/src/features/qr_checkin/presentation/qr_controller.dart`

## Platform sources not measured

- `lib/src/core/firebase_messaging_support_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/core/pending_token_storage_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/core/platform_http_client_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/core/query_param_sanitizer_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/core/web_notification_html.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/features/auth/data/session_storage_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/features/auth/presentation/widgets/google_auth_impl_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/features/events/calendar/calendar_file_export_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/features/events/presentation/event_form_browser_guard_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.
- `lib/src/features/profile/presentation/pages/avatar_file_picker_web.dart`: Browser-only adapter; Dart VM does not select this implementation. Browser functional checks are separate.

## Documented exclusions

- `lib/firebase_options.dart`: Generated localization/Firebase configuration, not handwritten application behavior.
- `lib/l10n/app_localizations.dart`: Generated localization/Firebase configuration, not handwritten application behavior.
- `lib/l10n/app_localizations_en.dart`: Generated localization/Firebase configuration, not handwritten application behavior.
- `lib/l10n/app_localizations_fr.dart`: Generated localization/Firebase configuration, not handwritten application behavior.

Coverage does not certify native providers, physical devices or store delivery.

[Source CI](https://github.com/theopeuchlestrade/fiestaaa_front/actions/runs/40725086602)
