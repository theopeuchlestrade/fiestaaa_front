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
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
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

  testWidgets('invalidated needs response reloads without a false load error', (
    tester,
  ) async {
    await seed();
    final oldItems = Completer<http.Response>();
    final oldContributions = Completer<http.Response>();
    var itemReads = 0;
    var contributionReads = 0;
    List<Map<String, Object>> contributions(int quantity) => [
      {'item_id': 1, 'quantity': quantity, 'email': fixture.guestEmail},
    ];
    Map<String, Object> item(String name) => {
      'event_id': 1,
      'item_id': 1,
      'type_id': 1,
      'type_name': 'Drink',
      'name_item': name,
      'max_quantity': 6,
      'reserved_quantity': 3,
      'item_kind': 'need',
    };
    await runZoned(
      () async {
        await tester.pumpWidget(page(session, EventModule.items));
        await tester.pump();
        expect(itemReads, 1);
        expect(contributionReads, 1);
        store.realtime(session.token, 1, 'event.items.changed');
        oldItems.complete(
          http.Response(jsonEncode([item('Outdated need')]), 200),
        );
        oldContributions.complete(
          http.Response(jsonEncode(contributions(2)), 200),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fresh need'), findsOneWidget);
        expect(find.text('Outdated need'), findsNothing);
        expect(
          find.text(
            S.of(tester.element(find.text('Fresh need'))).unableToLoadItems,
          ),
          findsNothing,
        );
        expect(itemReads, 2);
        expect(contributionReads, 2);
        expect(
          store
              .peek<List<ItemContributionModel>>(
                session.token,
                1,
                'contributions',
              )!
              .single
              .quantity,
          3,
        );
        expect(
          store
              .peek<List<EventItemModel>>(session.token, 1, 'items:all')!
              .single
              .name,
          'Fresh need',
        );
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((r) async {
          if (r.url.path.endsWith('/items')) {
            itemReads++;
            if (itemReads == 1) return oldItems.future;
            return http.Response(jsonEncode([item('Fresh need')]), 200);
          }
          if (r.url.path.endsWith('/items/contributions')) {
            contributionReads++;
            if (contributionReads == 1) return oldContributions.future;
            return http.Response(jsonEncode(contributions(3)), 200);
          }
          return http.Response('[]', 200);
        }),
      },
    );
  });

  testWidgets('invalidated poll response retries without a false load error', (
    tester,
  ) async {
    await seed();
    final oldPolls = Completer<http.Response>();
    var reads = 0;
    List<Map<String, Object>> polls(String question) => [
      {
        'poll_id': 1,
        'event_id': 1,
        'question': question,
        'allow_multiple': false,
        'expires_at': '2099-07-01',
        'created_at': '2026-01-01',
        'options': [
          {'option_id': 1, 'label': 'Salad', 'vote_count': 0},
        ],
        'total_votes': 0,
        'my_votes': <int>[],
      },
    ];
    await runZoned(
      () async {
        await tester.pumpWidget(page(session, EventModule.polls));
        await tester.pump();
        expect(reads, 1);
        store.realtime(session.token, 1, 'event.polls.changed');
        oldPolls.complete(
          http.Response(jsonEncode(polls('Outdated poll')), 200),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fresh poll'), findsOneWidget);
        expect(find.text('Outdated poll'), findsNothing);
        expect(
          find.text(
            S.of(tester.element(find.text('Fresh poll'))).unableToLoadPolls,
          ),
          findsNothing,
        );
        expect(reads, 2);
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((r) async {
          expect(r.url.path, '/events/1/polls');
          reads++;
          if (reads == 1) return oldPolls.future;
          return http.Response(jsonEncode(polls('Fresh poll')), 200);
        }),
      },
    );
  });

  testWidgets('discarded needs read never retries a cleared session', (
    tester,
  ) async {
    await seed();
    final oldItems = Completer<http.Response>();
    var reads = 0;
    await runZoned(
      () async {
        await tester.pumpWidget(page(session, EventModule.items));
        await tester.pump();
        expect(reads, 1);
        store.clear();
        oldItems.complete(http.Response('[]', 200));
        await tester.pumpAndSettle();
        expect(reads, 1);
        expect(
          store.peek<List<EventItemModel>>(session.token, 1, 'items:all'),
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((r) async {
          if (r.url.path.endsWith('/items')) {
            reads++;
            return oldItems.future;
          }
          return http.Response('[]', 200);
        }),
      },
    );
  });

  testWidgets(
    'invalidated filtered summary retries without dropping the list',
    (tester) async {
      await seed();
      final oldSummary = Completer<http.Response>();
      var allReads = 0;
      List<Map<String, Object>> items(int quantity) => [
        {
          'event_id': 1,
          'item_id': 1,
          'type_id': 1,
          'type_name': 'Drink',
          'name_item': 'Filtered need',
          'max_quantity': 6,
          'reserved_quantity': quantity,
          'item_kind': 'need',
        },
      ];
      await runZoned(
        () async {
          await tester.pumpWidget(page(session, EventModule.items));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Filter and sort'));
          await tester.pumpAndSettle();
          store.invalidate(1, ['items:all']);
          await tester.ensureVisible(
            find.byKey(const Key('items_scope_toCover')),
          );
          await tester.tap(find.byKey(const Key('items_scope_toCover')));
          await tester.pump();
          expect(allReads, 2);
          expect(find.text('Filtered need'), findsOneWidget);
          store.invalidate(1, ['items:all']);
          oldSummary.complete(http.Response(jsonEncode(items(2)), 200));
          await tester.pumpAndSettle();
          expect(find.text('Filtered need'), findsOneWidget);
          expect(
            find.text(
              S
                  .of(tester.element(find.text('Filtered need')))
                  .unableToLoadItems,
            ),
            findsNothing,
          );
          expect(allReads, 3);
          expect(
            store
                .peek<List<EventItemModel>>(session.token, 1, 'items:all')!
                .single
                .reservedQuantity,
            3,
          );
          await tester.pumpWidget(const SizedBox());
        },
        zoneValues: {
          apiHttpClientFactoryKey: () => MockClient((r) async {
            if (r.url.path.endsWith('/items')) {
              if (r.url.queryParameters['scope'] == 'all') {
                allReads++;
                if (allReads == 2) return oldSummary.future;
                return http.Response(
                  jsonEncode(items(allReads == 1 ? 1 : 3)),
                  200,
                );
              }
              return http.Response(jsonEncode(items(1)), 200);
            }
            return http.Response('[]', 200);
          }),
        },
      );
    },
  );
}
