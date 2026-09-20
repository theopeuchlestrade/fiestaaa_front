import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_route_page.dart';

final session = SessionData(token: 'test', email: 'guest@example.invalid');

void main() {
  testWidgets(
    'switching event routes loads the destination and ignores stale responses',
    (tester) async {
      final requests = <String>[];
      final first = Completer<http.Response>();
      final second = Completer<http.Response>();
      final api = EventsApi(
        client: MockClient((request) {
          requests.add(request.url.path);
          return request.url.path.endsWith('/1') ? first.future : second.future;
        }),
      );
      final router = GoRouter(
        initialLocation: '/events/1',
        routes: [
          GoRoute(
            path: '/events/:eventId',
            builder: (_, state) => EventRoutePage(
              session: session,
              eventId: int.parse(state.pathParameters['eventId']!),
              api: api,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('fr'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
        ),
      );
      await tester.pump();
      router.go('/events/2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, ['/events/1', '/events/2']);
      first.complete(http.Response('{}', 503));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      second.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      api.dispose();
    },
  );

  testWidgets('failed direct entry offers localized retry and a way home', (
    tester,
  ) async {
    var requests = 0;
    final api = EventsApi(
      client: MockClient((_) async {
        requests++;
        throw http.ClientException('offline');
      }),
    );
    final router = GoRouter(
      initialLocation: '/events/1',
      routes: [
        GoRoute(
          path: '/events',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/events/1',
          builder: (_, _) =>
              EventRoutePage(session: session, eventId: 1, api: api),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    api.dispose();
  });

  testWidgets('loading event can be left before a response arrives', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final api = EventsApi(client: MockClient((_) => pending.future));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EventRoutePage(session: session, eventId: 1, api: api),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    pending.complete(http.Response('{}', 503));
    await tester.pump();
    expect(tester.takeException(), isNull);
    api.dispose();
  });
}
