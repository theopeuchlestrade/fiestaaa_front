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

void main() {
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
