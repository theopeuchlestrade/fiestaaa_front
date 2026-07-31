import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/presentation/widgets/google_auth_helper.dart';
import 'package:google_identity_services_web/oauth2.dart';

class GoogleAuthImpl extends GoogleAuthHelper {
  @override
  Future<GoogleAuthResult?> signIn({
    required String? clientId,
    required List<String> scopes,
  }) async {
    if (clientId == null || clientId.isEmpty) {
      throw Exception('Client ID is required for Web Google Sign-In');
    }

    final completer = Completer<GoogleAuthResult?>();

    void safeComplete(GoogleAuthResult? result) {
      if (completer.isCompleted) return;
      completer.complete(result);
    }

    void safeCompleteError(Object error) {
      if (completer.isCompleted) return;
      completer.completeError(error);
    }

    final config = TokenClientConfig(
      client_id: clientId,
      scope: scopes,
      callback: (TokenResponse response) {
        if (response.error != null) {
          safeCompleteError(Exception('Google Auth Error: ${response.error}'));
          return;
        }

        final accessToken = response.access_token;
        if (accessToken != null && accessToken.isNotEmpty) {
          // The backend validates the token and fetches the verified Google
          // profile. Completing immediately avoids delaying auth on a second
          // browser-side request to the userinfo endpoint.
          safeComplete(GoogleAuthResult(accessToken: accessToken));
        } else {
          safeComplete(null);
        }
      },
      error_callback: (GoogleIdentityServicesError? error) {
        if (error?.type == GoogleIdentityServicesErrorType.popup_closed) {
          safeComplete(null);
          return;
        }
        final type =
            error?.type.toString() ??
            GoogleIdentityServicesErrorType.unknown.toString();
        final message = error?.message;
        safeCompleteError(
          Exception(
            message == null || message.isEmpty
                ? 'Google Auth Error: $type'
                : 'Google Auth Error: $type ($message)',
          ),
        );
      },
    );

    final client = oauth2.initTokenClient(config);

    // The SDK's error_callback handles popup closure. Keep a last-resort
    // timeout in case the third-party script never calls either callback.
    final timeoutTimer = Timer(const Duration(minutes: 2), () {
      safeComplete(null);
    });

    // Trigger the popup
    // explicit usage of requestAccessToken usually requires user interaction context
    client.requestAccessToken();

    return completer.future.whenComplete(() {
      timeoutTimer.cancel();
    });
  }
}

GoogleAuthHelper get googleAuthHelper => GoogleAuthImpl();
