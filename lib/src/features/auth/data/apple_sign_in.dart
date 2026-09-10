import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/config.dart';

bool get appleUsesAndroidCallback =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<AuthorizationCredentialAppleID> requestAppleCredential() async {
  final state = base64UrlEncode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  );
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    state: state,
    webAuthenticationOptions: kIsWeb || appleUsesAndroidCallback
        ? WebAuthenticationOptions(
            clientId: appleServiceId,
            redirectUri: appleUsesAndroidCallback
                ? buildApiUri('/auth/apple/android-callback')
                : Uri.parse(appleRedirectUri),
          )
        : null,
  );
  if (credential.state != state) {
    throw StateError('Apple authentication state mismatch');
  }
  return credential;
}
