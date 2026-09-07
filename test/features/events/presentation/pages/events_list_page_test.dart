import 'dart:async';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_response.dart' as response;
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/events_list_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _EventsApi extends EventsApi {
  int calls = 0;
  bool fail = false;
  bool failMore = false;
  final queries = <String?>[];
  Completer<response.Page<EventModel>>? delayed;

  @override
  Future<response.Page<EventModel>> fetchEventsPage({
    required String token,
    int limit = 50,
    String? cursor,
    String? query,
    String? view,
    String? sort,
  }) async {
    calls++;
    queries.add(query);
    if (fail || (failMore && cursor != null)) throw StateError('offline');
    if (delayed != null) {
      final pending = delayed!;
      delayed = null;
      return pending.future;
    }
    return cursor == null
        ? response.Page(items: [_event(1, 'First event')], nextCursor: 'next')
        : response.Page(items: [_event(2, 'Second event')]);
  }

  @override
  void dispose() {}
}

class _InvitationsApi extends InvitationsApi {
  bool fail = false;
  List<InvitationModel> items = [];
  @override
  Future<List<InvitationModel>> fetchMyInvitations(String token) async {
    if (fail) throw StateError('offline');
    return items;
  }

  @override
  void dispose() {}
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: S.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('loads cursor pages without replacing existing events', (
    tester,
  ) async {
    final api = _EventsApi();
    await tester.pumpWidget(
      _app(
        EventsListPage(
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: api,
          invitationsApi: _InvitationsApi(),
          onEventSelected: (_) async {},
          onOpenTrash: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First event'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('First event'), findsOneWidget);
    expect(find.text('Second event'), findsOneWidget);
    expect(api.calls, 2);
  });
  testWidgets('refresh preserves loaded pages and visible content on failure', (
    tester,
  ) async {
    final api = _EventsApi();
    final key = GlobalKey<EventsListPageState>();
    await tester.pumpWidget(
      _app(
        EventsListPage(
          key: key,
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: api,
          invitationsApi: _InvitationsApi(),
          onEventSelected: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(api.calls, 4);
    expect(find.text('Second event'), findsOneWidget);
    api.fail = true;
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(find.text('First event'), findsOneWidget);
    expect(find.textContaining('Unable to refresh'), findsOneWidget);
  });
  testWidgets('invitation failure preserves pending status and count', (
    tester,
  ) async {
    final invitations = _InvitationsApi()
      ..items = [
        InvitationModel(
          eventId: 1,
          email: 'me@example.com',
          status: 'Waiting',
          dateInvi: DateTime(2026),
          eventName: 'First event',
        ),
      ];
    final key = GlobalKey<EventsListPageState>();
    int? count;
    await tester.pumpWidget(
      _app(
        EventsListPage(
          key: key,
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: _EventsApi(),
          invitationsApi: invitations,
          onPendingInvitesChanged: (value) => count = value,
          onEventSelected: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(count, 1);
    invitations.fail = true;
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(find.textContaining('Invitations could not'), findsOneWidget);
  });
  testWidgets('debounces searches and ignores obsolete responses', (
    tester,
  ) async {
    final api = _EventsApi();
    final pending = Completer<response.Page<EventModel>>();
    api.delayed = pending;
    await tester.pumpWidget(
      _app(
        EventsListPage(
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: api,
          invitationsApi: _InvitationsApi(),
          onEventSelected: (_) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Party');
    await tester.pump(const Duration(milliseconds: 299));
    expect(api.calls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    pending.complete(response.Page(items: [_event(3, 'Obsolete')]));
    await tester.pumpAndSettle();
    expect(api.queries.last, 'Party');
    expect(find.text('Obsolete'), findsNothing);
  });
  testWidgets('load-more failure offers retry without clearing cards', (
    tester,
  ) async {
    final api = _EventsApi()..failMore = true;
    await tester.pumpWidget(
      _app(
        EventsListPage(
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: api,
          invitationsApi: _InvitationsApi(),
          onEventSelected: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('First event'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    api.failMore = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Second event'), findsOneWidget);
  });
  testWidgets('clear cancels a pending search before the debounce completes', (
    tester,
  ) async {
    final api = _EventsApi();
    await tester.pumpWidget(
      _app(
        EventsListPage(
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: api,
          invitationsApi: _InvitationsApi(),
          onEventSelected: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Birthday');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(api.queries, ['']);
  });
}
