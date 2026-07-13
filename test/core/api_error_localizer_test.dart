import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_error_localizer.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('known API codes are localized', () async {
    final l10n = await S.delegate.load(const Locale('en'));
    final error = ApiException(
      'message that must not be displayed',
      code: 'handle_taken',
    );

    expect(
      localizedApiError(l10n, error, fallback: l10n.actionFailed),
      l10n.identifierTaken,
    );
  });

  test('unknown API messages are replaced by a localized fallback', () async {
    final l10n = await S.delegate.load(const Locale('en'));
    final error = ApiException('Erreur interne non traduite');

    expect(
      localizedApiError(l10n, error, fallback: l10n.actionFailed),
      l10n.actionFailed,
    );
  });
}
