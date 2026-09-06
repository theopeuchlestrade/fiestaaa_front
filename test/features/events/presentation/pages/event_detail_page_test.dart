import 'dart:async';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_detail_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

EventModel _event(int id, String name) => EventModel(
  id: id,
  name: name,
  description: 'Description',
  date: DateTime(2099, 7, id),
  startTime: const Duration(hours: 20),
  endDate: null,
  endTime: null,
  address: 'Paris',
  latitude: null,
  longitude: null,
  paymentProviderId: null,
  paymentIdentifier: null,
  paymentRequestedAmount: null,
  paymentPerPerson: false,
  ownerEmail: 'me@example.com',
  playlistUrl: null,
  playlistProvider: null,
  enabledFeatures: const [],
);

class _Api extends EventsApi {
  Completer<EventModel>? pending;
  int? failure;
  @override
  Future<EventModel> fetchEventById({
    required String token,
    required int eventId,
  }) async {
    if (failure != null) throw ApiException('unavailable', statusCode: failure);
    if (pending != null) return pending!.future;
    return _event(eventId, 'Event $eventId');
  }

  @override
  Future<List<EventItemModel>> fetchEventItems(
    int eventId, {
    String? token,
    String? scope,
  }) async => [];
  @override
  Future<List<PollModel>> fetchEventPolls({
    required String token,
    required int eventId,
  }) async => [];
  @override
  Future<List<ItemContributionModel>> fetchEventItemContributions({
    required String token,
    required int eventId,
  }) async => [];
  @override
  void dispose() {}
}

class _Realtime extends RealtimeClient {
  _Realtime() : super(token: 'token');
  final messages = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get stream => messages.stream;
  @override
  void connect() {}
  void ready() => messages.add({'type': 'realtime.ready'});
  @override
  Future<void> dispose() async {
    unawaited(messages.close());
    await super.dispose();
  }
}

Widget _app(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('en'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: child,
    );

EventDetailPage _page(
  _Api api,
  int id,
  List<_Realtime> clients, {
  ValueChanged<int>? onRemoved,
}) => EventDetailPage(
  event: _event(id, 'Event $id'),
  session: SessionData(token: 'token', email: 'me@example.com'),
  eventsApi: api,
  invitationsApi: InvitationsApi(
    client: MockClient((_) async => http.Response('[]', 200)),
  ),
  paymentProvidersApi: PaymentProvidersApi(
    client: MockClient((_) async => http.Response('[]', 200)),
  ),
  realtimeClientFactory: (_, _) {
    final client = _Realtime();
    clients.add(client);
    return client;
  },
  onEventRemoved: onRemoved,
);

void main() {
  for (final status in [403, 404]) {
    testWidgets(
      'resync leaves the detail with an explanation on HTTP $status',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          _app(const Scaffold(body: Text('Events')), navigatorKey: navigator),
        );
        final api = _Api()..failure = status;
        final clients = <_Realtime>[];
        int? removed;
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  _page(api, 1, clients, onRemoved: (id) => removed = id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        clients.single.ready();
        await tester.pumpAndSettle();
        expect(removed, 1);
        expect(find.byType(EventDetailPage), findsNothing);
        expect(
          find.text('This fiestaaa was deleted or is no longer accessible.'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('ignores an old event response and a response after disposal', (
    tester,
  ) async {
    final api = _Api();
    final clients = <_Realtime>[];
    await tester.pumpWidget(_app(_page(api, 1, clients)));
    await tester.pumpAndSettle();
    final oldResponse = Completer<EventModel>();
    api.pending = oldResponse;
    clients.last.ready();
    await tester.pump();
    await tester.pumpWidget(_app(_page(api, 2, clients)));
    api.pending = null;
    oldResponse.complete(_event(1, 'Obsolete event'));
    await tester.pumpAndSettle();
    expect(find.text('Event 2'), findsOneWidget);
    expect(find.text('Obsolete event'), findsNothing);
    final lateResponse = Completer<EventModel>();
    api.pending = lateResponse;
    clients.last.ready();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    lateResponse.complete(_event(2, 'Late event'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
