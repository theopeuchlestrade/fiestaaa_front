import 'dart:async';
import 'dart:convert';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    as gp;
import 'package:sign_in_with_apple_platform_interface/sign_in_with_apple_platform_interface.dart'
    as ap;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Google extends gp.GoogleSignInPlatform {
  _Google(this.mode);
  final String mode;
  int authorizationCalls = 0;
  @override
  Future<void> init(gp.InitParameters params) async {}
  @override
  bool supportsAuthenticate() => true;
  @override
  bool authorizationRequiresUserInteraction() => false;
  @override
  Future<gp.AuthenticationResults> authenticate(
    gp.AuthenticateParameters params,
  ) async {
    if (mode == 'canceled') {
      throw const gp.GoogleSignInException(
        code: gp.GoogleSignInExceptionCode.canceled,
      );
    }
    if (mode == 'interrupted') {
      throw const gp.GoogleSignInException(
        code: gp.GoogleSignInExceptionCode.interrupted,
      );
    }
    if (mode == 'provider-failure') {
      throw const gp.GoogleSignInException(
        code: gp.GoogleSignInExceptionCode.providerConfigurationError,
        description: 'Fixture provider unavailable',
      );
    }
    if (mode == 'technical') throw StateError('fixture provider failure');
    return gp.AuthenticationResults(
      user: const gp.GoogleSignInUserData(
        email: 'qa@example.invalid',
        id: 'qa-google',
        displayName: 'QA User',
      ),
      authenticationTokens: gp.AuthenticationTokenData(
        idToken: mode == 'access' ? '' : 'fixture-id-token',
      ),
    );
  }

  @override
  Future<gp.ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    gp.ClientAuthorizationTokensForScopesParameters params,
  ) async {
    authorizationCalls++;
    return authorizationCalls == 1
        ? null
        : const gp.ClientAuthorizationTokenData(
            accessToken: 'fixture-access-token',
          );
  }

  @override
  Future<void> signOut(gp.SignOutParams params) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected Google platform call');
}

class _Apple extends ap.SignInWithApplePlatform {
  _Apple(this.mode);
  final String mode;
  String? requestedState;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ap.AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<ap.AppleIDAuthorizationScopes> scopes,
    ap.WebAuthenticationOptions? webAuthenticationOptions,
    String? nonce,
    String? state,
  }) async {
    requestedState = state;
    if (mode == 'canceled') {
      throw const ap.SignInWithAppleAuthorizationException(
        code: ap.AuthorizationErrorCode.canceled,
        message: 'Fixture cancelled',
      );
    }
    if (mode == 'failed') {
      throw const ap.SignInWithAppleAuthorizationException(
        code: ap.AuthorizationErrorCode.failed,
        message: 'Fixture failed',
      );
    }
    return ap.AuthorizationCredentialAppleID(
      authorizationCode: 'fixture-apple-code',
      identityToken: mode == 'missing-token' ? null : 'fixture-apple-token',
      state: mode == 'wrong-state' ? 'mismatch' : state,
      email: 'qa@example.invalid',
      givenName: 'QA',
      familyName: 'User',
      userIdentifier: 'qa-apple',
    );
  }
}

Widget app(Future<void> Function(SessionData) callback) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: AuthPage(onAuthenticated: callback),
);
void main() {
  for (final mode in [
    'id',
    'access',
    'canceled',
    'interrupted',
    'provider-failure',
    'technical',
    'server-refusal',
  ]) {
    testWidgets('Google $mode respects success/cancellation/error boundaries', (
      tester,
    ) async {
      final original = gp.GoogleSignInPlatform.instance;
      final google = _Google(mode);
      gp.GoogleSignInPlatform.instance = google;
      addTearDown(() => gp.GoogleSignInPlatform.instance = original);
      final requests = <http.Request>[];
      final sessions = <SessionData>[];
      await runZoned(
        () async {
          await tester.pumpWidget(
            app((s) async {
              sessions.add(s);
            }),
          );
          await tester.pumpAndSettle();
          final label = find.text('Continue with Google');
          await tester.ensureVisible(label);
          await tester.runAsync(() async {
            await tester.tap(label);
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pumpAndSettle();
          if (mode == 'id' || mode == 'access') {
            expect(sessions.single.email, 'qa@example.invalid');
            expect(requests.single.url.path, '/auth/oauth/google');
            final body = jsonDecode(requests.single.body) as Map;
            expect(
              body[mode == 'access' ? 'accessToken' : 'idToken'],
              mode == 'access' ? 'fixture-access-token' : 'fixture-id-token',
            );
            if (mode == 'access') expect(google.authorizationCalls, 2);
          } else {
            expect(sessions, isEmpty);
            expect(find.byType(SnackBar), findsOneWidget);
            if (mode != 'server-refusal') expect(requests, isEmpty);
            if (mode == 'canceled' || mode == 'interrupted') {
              expect(
                find.text(
                  S
                      .of(tester.element(find.byType(AuthPage)))
                      .googleLoginCancelled,
                ),
                findsOneWidget,
              );
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            requests.add(r);
            return http.Response(
              mode == 'server-refusal'
                  ? '{"error":"invalid_google_token"}'
                  : '{"token":"fixture-session","email":"qa@example.invalid"}',
              mode == 'server-refusal' ? 401 : 200,
            );
          }),
        },
      );
    });
  }
  for (final mode in [
    'success',
    'missing-token',
    'wrong-state',
    'canceled',
    'failed',
    'server-refusal',
  ]) {
    testWidgets(
      'Apple $mode validates state and never authenticates a refused response',
      (tester) async {
        final original = ap.SignInWithApplePlatform.instance;
        final apple = _Apple(mode);
        ap.SignInWithApplePlatform.instance = apple;
        addTearDown(() => ap.SignInWithApplePlatform.instance = original);
        final requests = <http.Request>[];
        final sessions = <SessionData>[];
        await runZoned(
          () async {
            await tester.pumpWidget(
              app((s) async {
                sessions.add(s);
              }),
            );
            await tester.pumpAndSettle();
            final label = find.text('Continue with Apple');
            await tester.ensureVisible(label);
            await tester.tap(label);
            await tester.pumpAndSettle();
            expect(apple.requestedState, isNotEmpty);
            if (mode == 'success') {
              expect(sessions.single.email, 'qa@example.invalid');
              expect(requests.single.url.path, '/auth/oauth/apple');
              expect(
                jsonDecode(requests.single.body),
                containsPair('authorizationCode', 'fixture-apple-code'),
              );
              expect(
                jsonDecode(requests.single.body),
                containsPair('name', 'QA User'),
              );
            } else {
              expect(sessions, isEmpty);
              expect(
                find.byType(SnackBar),
                mode == 'canceled' ? findsNothing : findsOneWidget,
              );
              if (mode != 'server-refusal') expect(requests, isEmpty);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
          zoneValues: {
            apiHttpClientFactoryKey: () => MockClient((r) async {
              requests.add(r);
              return http.Response(
                mode == 'server-refusal'
                    ? '{"error":"invalid_apple_code"}'
                    : '{"token":"fixture-session","email":"qa@example.invalid"}',
                mode == 'server-refusal' ? 503 : 200,
              );
            }),
          },
        );
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }
}
