import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';

String localizedApiError(S l10n, Object error, {required String fallback}) {
  if (error is ApiTransportException) {
    return l10n.networkError;
  }
  if (error is! ApiException) {
    return fallback;
  }

  return switch (error.code ?? error.message) {
    'geocoding_busy' => l10n.addressSearchBusy,
    'query_too_long' => l10n.addressSearchTooLong,
    'geocoding_unreachable' ||
    'geocoding_error' ||
    'geocoding_parse_error' => l10n.searchNotPossible,
    'token_used' => l10n.invitationLinkAlreadyUsed,
    'handle_taken' => l10n.identifierTaken,
    'invalid_credentials' => l10n.invalidCredentials,
    'email_not_verified' => l10n.loginRequiresVerifiedEmail,
    'invalid_handle' => l10n.pleaseEnterIdentifier,
    _ => fallback,
  };
}
