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
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_edit_page.dart';

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
  int deleted = 0;
  Completer<void>? deletePending;
  bool deleteFails = false;
  @override
  Future<void> deleteEvent({
    required String token,
    required int eventId,
  }) async {
    deleted++;
    if (deletePending != null) await deletePending!.future;
    if (deleteFails) throw ApiException('unavailable', statusCode: 503);
  }

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
  EventModel? event,
}) => EventDetailPage(
  event: event ?? _event(id, 'Event $id'),
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

class _GuestInvitations extends InvitationsApi {
  String status = 'Waiting';
  @override
  Future<List<InvitationModel>> fetchMyInvitations(String token) async => [
    InvitationModel(
      eventId: 1,
      email: 'guest@example.com',
      status: status,
      dateInvi: DateTime(2026),
    ),
  ];
  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'calendar and existing map pickers remain independently usable',
    (tester) async {
      final event = EventModel.fromJson({
        'event_id': 42,
        'name_event': 'Agenda and maps',
        'description': 'Test',
        'date_event': '2099-07-14',
        'start_time': '20:30:00',
        'address': 'Paris',
        'latitude': 48.8566,
        'longitude': 2.3522,
      });
      await tester.pumpWidget(_app(_page(_Api(), 42, [], event: event)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add to my calendar'));
      await tester.tap(find.text('Add to my calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Google Calendar'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      final maps = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).icon == Icons.place_outlined,
      );
      await tester.ensureVisible(maps);
      await tester.tap(maps);
      await tester.pumpAndSettle();
      final l10n = S.of(tester.element(find.byType(EventDetailPage)));
      expect(find.text(l10n.mapProviderGoogle), findsOneWidget);
      expect(find.text(l10n.mapProviderApple), findsOneWidget);
      expect(find.text(l10n.mapProviderOsm), findsOneWidget);
      expect(find.text('Google Calendar'), findsNothing);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('failed deletion keeps the editor and permits retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
    final api = _Api()..deleteFails = true;
    final clients = <_Realtime>[];
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(const Scaffold(body: Text('Events list')), navigatorKey: nav),
    );
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => _page(api, 1, clients)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Event actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit fiestaaa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete fiestaaa'));
    await tester.tap(find.text('Delete fiestaaa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditPage), findsOneWidget);
    expect(api.deleted, 1);
    api.deleteFails = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete fiestaaa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(api.deleted, 2);
    expect(find.text('Events list'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final pushed in [false, true]) {
    for (final realtime in [false, true]) {
      testWidgets(
        'deletion returns to list (pushed: $pushed, realtime: $realtime)',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tz.initializeTimeZones();
          final clients = <_Realtime>[];
          final api = _Api();
          final router = GoRouter(
            initialLocation: pushed ? '/events' : '/events/1',
            routes: [
              GoRoute(
                path: '/events',
                builder: (_, _) => const Scaffold(body: Text('Events list')),
              ),
              GoRoute(
                path: '/events/1',
                builder: (context, _) => _page(
                  api,
                  1,
                  clients,
                  onRemoved: (_) => context.go('/events'),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
            ),
          );
          if (pushed) {
            unawaited(router.push('/events/1'));
          }
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Event actions'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit fiestaaa'));
          await tester.pumpAndSettle();
          expect(find.byType(EventEditPage), findsOneWidget);
          await tester.ensureVisible(find.text('Delete fiestaaa'));
          await tester.tap(find.text('Delete fiestaaa'));
          await tester.pumpAndSettle();
          if (realtime) api.deletePending = Completer<void>();
          await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
          if (realtime) {
            await tester.pump();
          } else {
            await tester.pumpAndSettle();
          }
          if (realtime) {
            clients.single.messages.add({
              'type': 'event.deleted',
              'event_id': 1,
            });
            await tester.pump(const Duration(milliseconds: 16));
            api.deletePending!.complete();
            await tester.pumpAndSettle();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Events list'), findsOneWidget);
          expect(find.byType(EventEditPage), findsNothing);
          expect(router.routeInformationProvider.value.uri.path, '/events');
          expect(api.deleted, 1);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('address without coordinates offers maps on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(_app(_page(_Api(), 1, <_Realtime>[])));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Address'));
      await tester.tap(find.text('Address'));
      await tester.pumpAndSettle();
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Waze'), findsOneWidget);
      expect(find.text('OpenStreetMap'), findsOneWidget);
      expect(
        find.text('Apple Maps'),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('direct event back returns to the event list', (tester) async {
    final clients = <_Realtime>[];
    final router = GoRouter(
      initialLocation: '/events/1',
      routes: [
        GoRoute(
          path: '/events',
          builder: (_, _) => const Scaffold(body: Text('Events list')),
        ),
        GoRoute(
          path: '/events/1',
          builder: (_, _) => _page(_Api(), 1, clients),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Events list'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });

  testWidgets(
    'pending guest connects to event realtime only after acceptance',
    (tester) async {
      final clients = <_Realtime>[];
      final invitations = _GuestInvitations();
      await tester.pumpWidget(
        _app(
          EventDetailPage(
            event: _event(1, 'Event 1'),
            session: SessionData(token: 'token', email: 'guest@example.com'),
            eventsApi: _Api(),
            invitationsApi: invitations,
            paymentProvidersApi: PaymentProvidersApi(
              client: MockClient((_) async => http.Response('[]', 200)),
            ),
            realtimeClientFactory: (_, _) {
              final client = _Realtime();
              clients.add(client);
              return client;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(clients, isEmpty);
      invitations.status = 'Accepted';
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(clients, hasLength(1));
      invitations.status = 'Waiting';
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(clients.single.messages.isClosed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
