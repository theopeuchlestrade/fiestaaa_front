import 'dart:convert';
import 'package:fiestaaa_front/src/core/event_data_store.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const eventJson = {
  'event_id': 7,
  'name_event': 'Fixture party',
  'description': 'Fictional',
  'date_event': '2099-01-01',
  'start_time': '18:00:00',
  'address': 'Fictional',
  'owner_email': 'owner@example.invalid',
};
const itemJson = {
  'event_id': 7,
  'item_id': 9,
  'type_id': 1,
  'type_name': 'Drinks',
  'name_item': 'Water',
  'max_quantity': 6,
  'reserved_quantity': 2,
  'unit_label': 'bottles',
  'item_kind': 'need',
};
const pollJson = {
  'event_id': 7,
  'poll_id': 4,
  'question': 'Fixture menu',
  'allow_multiple': false,
  'expires_at': '2099-01-01T18:00:00Z',
  'created_at': '2026-01-01T18:00:00Z',
  'options': [
    {'option_id': 3, 'label': 'Salad', 'vote_count': 1},
  ],
};
const expenseJson = {
  'expense_id': 6,
  'event_id': 7,
  'title': 'Fixture groceries',
  'amount_cents': 2400,
  'paid_by_user_id': 1,
  'expense_date': '2099-01-01',
  'created_at': '2026-01-01',
  'participants': [],
};
final payload = EventPayload(
  name: 'Fixture party',
  description: 'Fictional',
  date: DateTime(2099),
  startTime: const Duration(hours: 18),
  address: 'Fictional',
  enabledFeatures: ['items', 'polls'],
);
const token = 'fixture-session';
typedef Invoke = Future<dynamic> Function(EventsApi);
final operations = <String, Invoke>{
  'addresses': (a) =>
      a.searchAddresses(token: token, query: 'Rue de la Paix', limit: 3),
  'events': (a) => a.fetchEvents(token: token),
  'event-page': (a) => a.fetchEventsPage(
    token: token,
    limit: 2,
    cursor: 'next',
    query: 'party dinner',
    view: 'accepted',
    sort: 'date',
  ),
  'create-event': (a) => a.createEvent(token: token, payload: payload),
  'update-event': (a) =>
      a.updateEvent(token: token, eventId: 7, payload: payload),
  'event': (a) => a.fetchEventById(token: token, eventId: 7),
  'items': (a) => a.fetchEventItems(7, token: token, scope: 'mine'),
  'polls': (a) => a.fetchEventPolls(token: token, eventId: 7),
  'create-poll': (a) => a.createEventPoll(
    token: token,
    eventId: 7,
    question: 'Fixture menu',
    options: ['Salad', 'Pizza'],
    durationMinutes: 30,
    allowMultiple: false,
  ),
  'vote': (a) =>
      a.votePoll(token: token, eventId: 7, pollId: 4, optionIds: [3]),
  'delete-poll': (a) => a.deleteEventPoll(token: token, eventId: 7, pollId: 4),
  'contributions': (a) =>
      a.fetchEventItemContributions(token: token, eventId: 7),
  'reserve': (a) =>
      a.reserveEventItem(token: token, eventId: 7, itemId: 9, quantity: 2),
  'create-item': (a) => a.createCustomEventItem(
    token: token,
    eventId: 7,
    name: 'Water',
    maxQuantity: 6,
    unitLabel: 'bottles',
    itemKind: EventItemKind.need,
  ),
  'delete-item': (a) => a.deleteEventItem(token: token, eventId: 7, itemId: 9),
  'share': (a) => a.createShareLink(token: token, eventId: 7),
  'claim': (a) => a.claimShareToken(token: token, shareToken: 'single-use'),
  'delete-event': (a) => a.deleteEvent(token: token, eventId: 7),
  'trash': (a) => a.fetchTrashedEvents(token: token),
  'restore': (a) => a.restoreEvent(token: token, eventId: 7),
  'expenses': (a) => a.fetchEventExpenses(token: token, eventId: 7),
  'summary': (a) => a.fetchEventExpensesSummary(token: token, eventId: 7),
  'create-expense': (a) => a.createEventExpense(
    token: token,
    eventId: 7,
    title: 'Fixture groceries',
    amountCents: 2400,
    paidByUserId: 1,
    participantUserIds: [1, 2],
    note: 'Fictional',
    expenseDate: DateTime.utc(2099, 1, 1),
  ),
  'delete-expense': (a) =>
      a.deleteEventExpense(token: token, eventId: 7, expenseId: 6),
};
Object responseBody(String name) => switch (name) {
  'addresses' => [
    {'label': 'Rue de la Paix', 'latitude': 48.85, 'longitude': 2.35},
  ],
  'events' || 'event-page' || 'trash' => [eventJson],
  'items' => [itemJson],
  'polls' => [pollJson],
  'create-poll' || 'vote' => pollJson,
  'reserve' || 'create-item' => itemJson,
  'contributions' => [
    {
      'item_id': 9,
      'quantity': 2,
      'email': 'guest@example.invalid',
      'handle': 'guest',
    },
  ],
  'share' => {'token': 'single-use'},
  'claim' => {'event': eventJson},
  'expenses' => [expenseJson],
  'summary' => {
    'currency': 'EUR',
    'total_expenses_cents': 2400,
    'balances': [],
    'settlements': [],
  },
  'create-expense' => expenseJson,
  'delete-poll' || 'delete-item' || 'delete-event' || 'delete-expense' => {},
  _ => eventJson,
};
void main() {
  setUp(EventDataStore.instance.clear);
  tearDown(EventDataStore.instance.clear);
  for (final entry in operations.entries) {
    test(
      '${entry.key} preserves auth and decodes its public response',
      () async {
        final requests = <http.Request>[];
        final api = EventsApi(
          client: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(responseBody(entry.key)),
              [
                    'create-event',
                    'create-poll',
                    'share',
                    'create-expense',
                  ].contains(entry.key)
                  ? 201
                  : 200,
              headers: entry.key == 'event-page'
                  ? {'x-next-cursor': 'after'}
                  : {},
            );
          }),
        );
        final result = await entry.value(api);
        expect(
          requests.every((r) => r.headers['Authorization'] == 'Bearer $token'),
          isTrue,
        );
        expect(
          requests.every(
            (r) =>
                r.url.path.contains('/events') ||
                r.url.path == '/share/claim' ||
                r.url.path == '/geo/address-search',
          ),
          isTrue,
        );
        switch (entry.key) {
          case 'event-page':
            expect(result.nextCursor, 'after');
            expect(result.items.single.id, 7);
            expect(requests.single.url.queryParameters['q'], 'party dinner');
            expect(requests.single.url.queryParameters['cursor'], 'next');
          case 'events' || 'trash':
            expect(result.single.name, 'Fixture party');
          case 'create-event' ||
              'update-event' ||
              'event' ||
              'claim' ||
              'restore':
            expect(result.id, 7);
            expect(result.name, 'Fixture party');
          case 'items':
            expect(result.single.itemId, 9);
            expect(requests.single.url.queryParameters['scope'], 'mine');
          case 'polls':
            expect(result.single.question, 'Fixture menu');
          case 'create-poll' || 'vote':
            expect(result.question, 'Fixture menu');
          case 'contributions':
            expect(result.single.quantity, 2);
            expect(result.single.email, 'guest@example.invalid');
          case 'reserve' || 'create-item':
            expect(result.itemId, 9);
          case 'share':
            expect(result, 'single-use');
          case 'addresses':
            expect(result.single.latitude, 48.85);
            expect(requests.single.url.queryParameters['q'], 'Rue de la Paix');
          case 'expenses':
            expect(result.single.amountCents, 2400);
          case 'summary':
            expect(result.totalExpensesCents, 2400);
          case 'create-expense':
            expect(result.amountCents, 2400);
            expect(
              jsonDecode(requests.single.body),
              containsPair('participant_user_ids', [1, 2]),
            );
            expect(
              jsonDecode(requests.single.body),
              containsPair('expense_date', '2099-01-01T00:00:00.000Z'),
            );
        }
        api.dispose();
      },
    );
    test(
      '${entry.key} preserves a server permission refusal without a result',
      () async {
        final api = EventsApi(
          client: MockClient(
            (_) async => http.Response('{"error":"forbidden"}', 403),
          ),
        );
        await expectLater(
          entry.value(api),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', 403)
                .having((e) => e.code, 'code', 'forbidden'),
          ),
        );
        api.dispose();
      },
    );
  }
  test(
    'expired poll vote is reported as expiration rather than a successful vote',
    () async {
      final api = EventsApi(
        client: MockClient(
          (_) async => http.Response('{"error":"poll_expired"}', 410),
        ),
      );
      await expectLater(
        api.votePoll(token: token, eventId: 7, pollId: 4, optionIds: [3]),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'expiry', 410)),
      );
      api.dispose();
    },
  );
  test(
    'complete expenses follow cursor pages without dropping earlier rows',
    () async {
      final requests = <http.Request>[];
      final api = EventsApi(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode([
              {...expenseJson, 'expense_id': requests.length},
            ]),
            200,
            headers: requests.length == 1 ? {'x-next-cursor': 'second'} : {},
          );
        }),
      );
      final rows = await api.fetchEventExpenses(token: token, eventId: 7);
      expect(rows.map((e) => e.id), [1, 2]);
      expect(requests.last.url.queryParameters['cursor'], 'second');
      api.dispose();
    },
  );
}
