import 'dart:async';
import 'dart:convert';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget app(AuthPage page) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: page,
);
S labels(WidgetTester tester) => S.of(tester.element(find.byType(AuthPage)));
Future<void> tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'incoming completion link replaces stale form fields and leaving completion returns to login',
    (tester) async {
      Future<void> authenticated(SessionData _) async {}
      await tester.pumpWidget(app(AuthPage(onAuthenticated: authenticated)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'olduser');
      await tester.pumpWidget(
        app(
          AuthPage(
            onAuthenticated: authenticated,
            pendingRegistrationToken: 'fixture-completion',
            flashCode: 'complete_registration_ready',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = labels(tester);
      expect(find.text(l.completeRegistrationReady), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(
        app(
          AuthPage(onAuthenticated: authenticated, flashCode: 'email_verified'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(l.emailVerified), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.pumpWidget(
        app(
          AuthPage(
            onAuthenticated: authenticated,
            flashCode: 'session_expired',
            flashIsError: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(l.sessionExpired), findsOneWidget);
      await tester.pumpWidget(
        app(
          AuthPage(
            onAuthenticated: authenticated,
            flashCode: 'email_verification_failed',
            flashIsError: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(l.emailVerificationFailed), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('empty login reports validation without making a request', (
    tester,
  ) async {
    var calls = 0;
    await runZoned(
      () async {
        await tester.pumpWidget(app(AuthPage(onAuthenticated: (_) async {})));
        await tester.pumpAndSettle();
        final l = labels(tester);
        await tap(tester, l.signIn);
        expect(find.text(l.pleaseEnterIdentifierLogin), findsOneWidget);
        expect(find.text(l.passwordRequired), findsOneWidget);
        expect(calls, 0);
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((_) async {
          calls++;
          return http.Response('{}', 500);
        }),
      },
    );
  });
  testWidgets(
    'login trims identity, authenticates once and shows confirmation',
    (tester) async {
      final requests = <http.Request>[];
      final sessions = <SessionData>[];
      await runZoned(
        () async {
          await tester.pumpWidget(
            app(
              AuthPage(
                onAuthenticated: (s) async {
                  sessions.add(s);
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField).at(0),
            '  qauser  ',
          );
          await tester.enterText(find.byType(TextFormField).at(1), 'fixture');
          final l = labels(tester);
          await tap(tester, l.signIn);
          expect(sessions.single.email, 'qa@example.invalid');
          expect(jsonDecode(requests.single.body), {
            'identifier': 'qauser',
            'password': 'fixture',
          });
          expect(find.text(l.loginSuccess), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            requests.add(r);
            return http.Response(
              '{"token":"fixture","email":"qa@example.invalid"}',
              200,
            );
          }),
        },
      );
    },
  );
  for (final code in [
    'invalid_credentials',
    'email_not_verified',
    'rate_limited',
  ]) {
    testWidgets('login refusal $code is translated and allows retry', (
      tester,
    ) async {
      var calls = 0;
      var authenticated = false;
      await runZoned(
        () async {
          await tester.pumpWidget(
            app(
              AuthPage(
                onAuthenticated: (_) async {
                  authenticated = true;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField).at(0), 'qauser');
          await tester.enterText(find.byType(TextFormField).at(1), 'fixture');
          await tap(tester, labels(tester).signIn);
          expect(find.text(code), findsNothing);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(authenticated, isFalse);
          expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNotNull,
          );
          expect(calls, 1);
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({'error': code}),
              code == 'rate_limited' ? 429 : 401,
            );
          }),
        },
      );
    });
  }
  testWidgets(
    'registration validates email then returns to login with generic confirmation',
    (tester) async {
      final requests = <http.Request>[];
      await runZoned(
        () async {
          await tester.pumpWidget(app(AuthPage(onAuthenticated: (_) async {})));
          await tester.pumpAndSettle();
          final l = labels(tester);
          await tap(tester, l.register);
          expect(find.byType(TextFormField), findsOneWidget);
          await tester.enterText(find.byType(TextFormField), 'invalid');
          await tap(tester, l.sendVerificationLink);
          expect(find.text(l.invalidEmail), findsOneWidget);
          expect(requests, isEmpty);
          await tester.enterText(
            find.byType(TextFormField),
            'qa@example.invalid',
          );
          await tap(tester, l.sendVerificationLink);
          expect(requests.single.url.path, '/auth/register');
          expect(find.text(l.verificationPending), findsOneWidget);
          expect(find.byType(TextFormField), findsNWidgets(2));
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            requests.add(r);
            return http.Response('{}', 201);
          }),
        },
      );
    },
  );
  testWidgets(
    'registration completion validates handle, strength and confirmation',
    (tester) async {
      final requests = <http.Request>[];
      SessionData? authenticated;
      await runZoned(
        () async {
          await tester.pumpWidget(
            app(
              AuthPage(
                pendingRegistrationToken: 'one-use',
                onAuthenticated: (s) async {
                  authenticated = s;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = labels(tester);
          await tester.enterText(find.byType(TextFormField).at(0), 'BAD!');
          await tester.enterText(find.byType(TextFormField).at(1), 'short');
          await tester.enterText(find.byType(TextFormField).at(2), 'different');
          await tap(tester, l.finishAccountSetup);
          expect(find.text(l.identifierFormat), findsOneWidget);
          expect(find.text(l.passwordMinLength), findsOneWidget);
          expect(find.text(l.passwordsDoNotMatch), findsOneWidget);
          expect(requests, isEmpty);
          await tester.enterText(find.byType(TextFormField).at(0), 'qauser');
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'alllowercasepassword',
          );
          await tester.enterText(
            find.byType(TextFormField).at(2),
            'alllowercasepassword',
          );
          await tap(tester, l.finishAccountSetup);
          expect(find.text(l.passwordRequirements), findsOneWidget);
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'FixturePassword1!',
          );
          await tester.enterText(
            find.byType(TextFormField).at(2),
            'FixturePassword1!',
          );
          await tap(tester, l.finishAccountSetup);
          expect(authenticated?.email, 'qa@example.invalid');
          expect(requests.single.url.path, '/auth/complete-registration');
          expect((jsonDecode(requests.single.body) as Map)['token'], 'one-use');
          expect(find.text(l.registrationCompleted), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            requests.add(r);
            return http.Response(
              '{"token":"fixture","email":"qa@example.invalid"}',
              200,
            );
          }),
        },
      );
    },
  );
  testWidgets(
    'transport interruption retains login input and presents retryable error',
    (tester) async {
      await runZoned(
        () async {
          await tester.pumpWidget(app(AuthPage(onAuthenticated: (_) async {})));
          await tester.pumpAndSettle();
          final l = labels(tester);
          await tester.enterText(find.byType(TextFormField).at(0), 'qauser');
          await tester.enterText(find.byType(TextFormField).at(1), 'fixture');
          await tap(tester, l.signIn);
          expect(find.text(l.networkError), findsOneWidget);
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).at(0))
                .controller
                ?.text,
            'qauser',
          );
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient(
            (_) async => throw http.ClientException('fixture offline'),
          ),
        },
      );
    },
  );
  testWidgets(
    'password visibility toggle and mode changes do not expose stale passwords',
    (tester) async {
      await tester.pumpWidget(app(AuthPage(onAuthenticated: (_) async {})));
      await tester.pumpAndSettle();
      final l = labels(tester);
      await tester.enterText(find.byType(TextFormField).at(1), 'fixture');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(TextFormField).at(1),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show or hide password'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(TextFormField).at(1),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      await tap(tester, l.register);
      await tap(tester, l.login);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller
            ?.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
