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

  return switch (error.code) {
    'handle_taken' => l10n.identifierTaken,
    'invalid_handle' => l10n.pleaseEnterIdentifier,
    _ => fallback,
  };
}
