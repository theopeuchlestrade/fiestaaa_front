import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/event_data_store.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_route_page.dart';
import '../../../../../tool/navigation_benchmark.dart' as fixture;

class _Quiet extends RealtimeClient {
  _Quiet(String token, int event) : super(token: token, eventId: event);
  @override
  void connect() {}
}

Widget page(SessionData session, EventModule module) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: EventRoutePage(
    session: session,
    eventId: 1,
    module: module,
    realtimeClientFactory: _Quiet.new,
  ),
);
void main() {
  final store = EventDataStore.instance;
  final session = SessionData(token: 'cache-test', email: fixture.guestEmail);
  setUp(() {
    store.clear();
    store.bind(session.token, session.email);
  });
  tearDown(store.clear);
  Future<void> seed({String status = 'Accepted'}) async {
    await store.read(
      session.token,
      1,
      'context',
      () async => EventModel.fromJson(fixture.fixtureEvent),
    );
    await store.read<InvitationModel?>(
      session.token,
      1,
      'access',
      () async => InvitationModel.fromJson({
        ...fixture.fixtureInvitations.last,
        'status': status,
      }),
    );
  }

  testWidgets(
    'warm needs renders before a frame without duplicate network requests',
    (tester) async {
      await seed();
      final items = [
        EventItemModel.fromJson({
          'event_id': 1,
          'item_id': 1,
          'type_id': 1,
          'type_name': 'Drink',
          'name_item': 'Fixture drinks',
          'max_quantity': 6,
          'reserved_quantity': 2,
          'item_kind': 'need',
        }),
      ];
      await store.read(session.token, 1, 'items:all', () async => items);
      final requests = <String>[];
      await runZoned(
        () async {
          await tester.pumpWidget(page(session, EventModule.items));
          expect(find.text('Fixture drinks'), findsOneWidget);
          await tester.pump();
          expect(
            requests.where(
              (p) =>
                  p.endsWith('/items') ||
                  p.endsWith('/events/1') ||
                  p.endsWith('/polls'),
            ),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            requests.add(r.url.path);
            return http.Response('[]', 200);
          }),
        },
      );
    },
  );
  testWidgets('expenses loads only its resources and shared membership', (
    tester,
  ) async {
    await seed();
    final requests = <String>[];
    await runZoned(
      () async {
        await tester.pumpWidget(page(session, EventModule.expenses));
        await tester.pumpAndSettle();
        expect(
          requests,
          containsAll([
            '/events/1/expenses',
            '/events/1/expenses/summary',
            '/events/1/invitations',
          ]),
        );
        expect(
          requests.any(
            (p) =>
                p.contains('/items') ||
                p.contains('/polls') ||
                p.contains('payment'),
          ),
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((r) async {
          requests.add(r.url.path);
          final body = r.url.path.endsWith('/summary')
              ? {
                  'currency': 'EUR',
                  'total_expenses_cents': 0,
                  'balances': [],
                  'settlements': [],
                }
              : [];
          return http.Response(jsonEncode(body), 200);
        }),
      },
    );
  });
  testWidgets('expense list renders while concurrent summary remains pending', (
    tester,
  ) async {
    await seed();
    final summary = Completer<http.Response>();
    final requests = <String>[];
    await runZoned(
      () async {
        await tester.pumpWidget(page(session, EventModule.expenses));
        await tester.pump();
        expect(
          requests,
          containsAll([
            '/events/1/expenses',
            '/events/1/expenses/summary',
            '/events/1/invitations',
          ]),
        );
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('Fixture expense'), findsOneWidget);
        expect(summary.isCompleted, isFalse);
        summary.complete(
          http.Response(
            jsonEncode({
              'currency': 'EUR',
              'total_expenses_cents': 2400,
              'balances': [],
              'settlements': [],
            }),
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fixture expense'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((r) async {
          requests.add(r.url.path);
          if (r.url.path.endsWith('/summary')) return summary.future;
          final body = r.url.path.endsWith('/expenses')
              ? [
                  {
                    'expense_id': 1,
                    'event_id': 1,
                    'paid_by_user_id': 1,
                    'paid_by_handle': 'benchowner',
                    'title': 'Fixture expense',
                    'amount_cents': 2400,
                    'expense_date': '2099-07-01',
                    'created_at': '2026-01-01',
                    'participants': [],
                  },
                ]
              : fixture.fixtureInvitations;
          return http.Response(jsonEncode(body), 200);
        }),
      },
    );
  });
  testWidgets(
    'pending invitation cannot reuse another role protected snapshot',
    (tester) async {
      await seed(status: 'Waiting');
      await store.read(
        session.token,
        1,
        'items:all',
        () async => <EventItemModel>[],
      );
      final requests = <String>[];
      await runZoned(
        () async {
          await tester.pumpWidget(page(session, EventModule.items));
          await tester.pumpAndSettle();
          expect(
            find.text('Accept the invitation to access this module.'),
            findsOneWidget,
          );
          expect(requests, isEmpty);
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            requests.add(r.url.path);
            return http.Response('[]', 200);
          }),
        },
      );
    },
  );
  test(
    'expired or invalidated access cannot make protected cache fresh',
    () async {
      await seed();
      expect(store.canReuseProtected(session.token, 1), isTrue);
      store.invalidate(1, ['access']);
      expect(store.canReuseProtected(session.token, 1), isFalse);
    },
  );
  test('successful API mutation invalidates dependent snapshots', () async {
    await seed();
    await store.read(session.token, 1, 'polls', () async => 1);
    final client = ApiHttpClient(
      MockClient((_) async => http.Response('{}', 200)),
      clientVersion: Future.value('test'),
    );
    await client.patch(
      Uri.parse('http://localhost/events/1/polls/1'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    expect(store.isFresh(session.token, 1, 'polls'), isFalse);
    client.close();
  });
  test('event API shares a complete read across independent clients', () async {
    var reads = 0;
    final pending = Completer<http.Response>();
    final one = EventsApi(
      client: MockClient((_) {
        reads++;
        return pending.future;
      }),
    );
    final two = EventsApi(
      client: MockClient((_) {
        reads++;
        return pending.future;
      }),
    );
    final a = one.fetchEventById(token: session.token, eventId: 1);
    final b = two.fetchEventById(token: session.token, eventId: 1);
    pending.complete(http.Response(jsonEncode(fixture.fixtureEvent), 200));
    expect((await a).name, (await b).name);
    expect(reads, 1);
    one.dispose();
    two.dispose();
  });
  testWidgets('failed background context refresh retains overview with retry', (
    tester,
  ) async {
    await seed();
    store.invalidate(1, ['context']);
    await runZoned(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: EventRoutePage(
              session: session,
              eventId: 1,
              realtimeClientFactory: _Quiet.new,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Performance fixture'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () =>
            MockClient((_) async => http.Response('{}', 503)),
      },
    );
  });
}
