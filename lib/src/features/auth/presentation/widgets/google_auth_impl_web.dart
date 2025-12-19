import 'dart:async';
import 'dart:js_interop';

import 'package:fiestaaa_front/src/features/auth/presentation/widgets/google_auth_helper.dart';
import 'package:google_identity_services_web/oauth2.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'dart:convert';

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

    // GIS token client callback is not always invoked when the user closes the popup.
    // We use a "focus returned" heuristic + a safety timeout to avoid hanging forever.
    var gotResponse = false;
    final startedAt = DateTime.now();
    JSFunction? focusListener;
    Timer? timeoutTimer;

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
      callback: (TokenResponse response) async {
        gotResponse = true;
        if (response.error != null) {
          safeCompleteError(Exception('Google Auth Error: ${response.error}'));
          return;
        }

        if (response.access_token != null) {
          try {
            // We have an access token. To be useful, we often want the user's email/profile
            // to display in the UI immediately, although the backend will verify the token.
            // We fetch the user info manually from the OIDC userinfo endpoint.
            // This endpoint is standard OIDC and typically does NOT require "People API" enablement
            // in the same way the plugin's internal calls do.
            final userInfoResponse = await http.get(
              Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
              headers: {'Authorization': 'Bearer ${response.access_token}'},
            );

            if (userInfoResponse.statusCode == 200) {
              final userData = jsonDecode(userInfoResponse.body);
              safeComplete(GoogleAuthResult(
                accessToken: response.access_token,
                email: userData['email'],
                displayName: userData['name'],
                photoUrl: userData['picture'],
                idToken: null, // Token flow gives access_token primarily
              ));
            } else {
              // Even if userinfo fails, we have the token, so we can might still proceed?
              // But usually we need at least the email to update the UI.
              // Let's assume validation happens on backend.
              safeComplete(GoogleAuthResult(
                accessToken: response.access_token,
              ));
            }
          } catch (e) {
            // Fallback: return just the token
            safeComplete(GoogleAuthResult(
              accessToken: response.access_token,
            ));
          }
        } else {
          safeComplete(null);
        }
      },
    );

    final client = oauth2.initTokenClient(config);

    // If the popup closes, the browser focus returns to this page.
    // If we still don't have a response shortly after, treat it as a cancel.
    focusListener = ((web.Event _) {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < const Duration(milliseconds: 250)) return;
      if (gotResponse || completer.isCompleted) return;

      // Give GIS a small chance to deliver the callback after focus returns.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (gotResponse || completer.isCompleted) return;
        safeComplete(null);
      });
    }).toJS;
    web.window.addEventListener('focus', focusListener);

    // Safety timeout (should rarely happen, but avoids infinite loading).
    timeoutTimer = Timer(const Duration(minutes: 2), () {
      if (gotResponse || completer.isCompleted) return;
      safeComplete(null);
    });

    // Trigger the popup
    // explicit usage of requestAccessToken usually requires user interaction context
    client.requestAccessToken();

    return completer.future.whenComplete(() {
      timeoutTimer?.cancel();
      web.window.removeEventListener('focus', focusListener);
    });
  }
}

GoogleAuthHelper get googleAuthHelper => GoogleAuthImpl();
