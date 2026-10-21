import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/features/home/presentation/pages/home_page.dart';
import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:fiestaaa_front/src/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_route_page.dart';

class _Storage implements SessionStorageBackend {
  final values = <String, String>{};
  @override
  Future<void> write({required String key, String? value}) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class _Auth extends AuthApi {
  @override
  Future<SessionData?> validateSession(String token) async =>
      SessionData(token: token, email: 'demo@example.invalid');
}

class _RestoredAuth extends _Auth {
  _RestoredAuth(this.mode);
  final String mode;
  int logouts = 0;
  @override
  Future<SessionData?> validateSession(String token) async {
    if (mode == 'offline') throw StateError('offline');
    if (mode == 'expired') return null;
    return SessionData(
      token: token,
      email: 'demo@example.invalid',
      handle: 'restored',
    );
  }

  @override
  Future<void> logout({String? token}) async {
    logouts++;
    if (mode == 'offline') throw StateError('offline');
  }
}

void main() {
  for (final mode in ['valid', 'expired', 'offline']) {
    testWidgets(
      'restored session $mode validates without confusing outage with expiry',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        SessionStorage.debugSetStorageBackend(_Storage());
        addTearDown(SessionStorage.debugResetStorageBackend);
        await SessionStorage.save(
          SessionData(token: 'saved-token', email: 'demo@example.invalid'),
        );
        final auth = _RestoredAuth(mode);
        await runZoned(
          () async {
            await tester.pumpWidget(
              FiestaaaApp(initialLocation: '/events', authApi: auth),
            );
            await tester.pumpAndSettle();
            if (mode == 'expired') {
              expect(find.byType(AuthPage), findsOneWidget);
              expect(await SessionStorage.load(), isNull);
            } else {
              expect(find.byType(HomePage), findsOneWidget);
              expect((await SessionStorage.load())!.token, 'saved-token');
              tester.widget<HomePage>(find.byType(HomePage)).onLogout();
              await tester.pumpAndSettle();
              expect(auth.logouts, 1);
              expect(find.byType(AuthPage), findsOneWidget);
              expect(await SessionStorage.load(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
          zoneValues: {
            apiHttpClientFactoryKey: () =>
                MockClient((_) async => http.Response('{}', 503)),
          },
        );
      },
    );
  }
  for (final page in ['privacy', 'terms', 'support', 'delete-account']) {
    testWidgets('public $page route is accessible without a session', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      SessionStorage.debugSetStorageBackend(_Storage());
      addTearDown(SessionStorage.debugResetStorageBackend);
      await tester.pumpWidget(
        FiestaaaApp(initialLocation: '/$page', authApi: _Auth()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LegalPage), findsOneWidget);
      expect(tester.widget<LegalPage>(find.byType(LegalPage)).page, page);
      expect(find.byType(AuthPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'reset token link remains public and is passed to the recovery page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      SessionStorage.debugSetStorageBackend(_Storage());
      addTearDown(SessionStorage.debugResetStorageBackend);
      await tester.pumpWidget(
        FiestaaaApp(
          initialLocation: '/reset-password?token=fictional-reset',
          authApi: _Auth(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetPage), findsOneWidget);
      expect(
        tester.widget<PasswordResetPage>(find.byType(PasswordResetPage)).token,
        'fictional-reset',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  test('event route IDs accept positive integers only', () {
    expect(parseEventRouteId('42'), 42);
    expect(parseEventRouteId('0'), isNull);
    expect(parseEventRouteId('-1'), isNull);
    expect(parseEventRouteId('not-an-id'), isNull);
    expect(parseEventRouteId(null), isNull);
  });
  for (final module in EventModule.values) {
    testWidgets('direct ${module.name} link resumes after sign-in', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      SessionStorage.debugSetStorageBackend(_Storage());
      addTearDown(SessionStorage.debugResetStorageBackend);
      final path = '/events/42/${module.name}';
      await tester.pumpWidget(
        FiestaaaApp(initialLocation: path, authApi: _Auth()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      await tester
          .widget<AuthPage>(find.byType(AuthPage))
          .onAuthenticated(
            SessionData(token: 'test', email: 'demo@example.invalid'),
          );
      await tester.pumpAndSettle();
      final page = tester.widget<EventRoutePage>(find.byType(EventRoutePage));
      expect(page.eventId, 42);
      expect(page.module, module);
      expect(
        GoRouter.of(
          tester.element(find.byType(EventRoutePage)),
        ).routeInformationProvider.value.uri.path,
        path,
      );
      final router = GoRouter.of(tester.element(find.byType(EventRoutePage)));
      router.push('/events/43/${module.name}');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/events/43/${module.name}',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
