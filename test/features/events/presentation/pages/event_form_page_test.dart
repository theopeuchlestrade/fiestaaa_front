import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/event_form_session.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_create_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_edit_page.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../event_form_session_test.dart' as data;
import '../widgets/event_personal_summary_test.dart' as fixtures;

class _Api extends EventsApi {
  bool fail = false;
  int created = 0;
  int updated = 0;
  int deleted = 0;
  EventPayload? lastPayload;
  @override
  Future<EventModel> updateEvent({
    required String token,
    required int eventId,
    required EventPayload payload,
  }) async {
    updated++;
    lastPayload = payload;
    if (fail) throw StateError('offline');
    return fixtures.event();
  }

  @override
  Future<void> deleteEvent({
    required String token,
    required int eventId,
  }) async {
    deleted++;
    if (fail) throw StateError('offline');
  }

  @override
  Future<List<AddressSuggestion>> searchAddresses({
    required String token,
    required String query,
    int limit = 5,
  }) async => [
    AddressSuggestion(label: 'Paris, France', latitude: 48.85, longitude: 2.35),
  ];
  @override
  Future<EventModel> createEvent({
    required String token,
    required EventPayload payload,
  }) async {
    created++;
    if (fail) throw StateError('offline');
    return fixtures.event();
  }

  @override
  void dispose() {}
}

Widget app(Widget page) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: Scaffold(body: page),
);
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
  });
  PaymentProvidersApi providers() => PaymentProvidersApi(
    client: MockClient((_) async => http.Response('[]', 200)),
  );
  testWidgets(
    'restores a local draft and revalidates its address before creation',
    (tester) async {
      const store = EventDraftStore();
      await store.write('me@example.com', data.fields('Birthday'));
      final api = _Api()..fail = true;
      var completed = false;
      await tester.pumpWidget(
        app(
          EventCreatePage(
            session: SessionData(token: 'token', email: 'me@example.com'),
            eventsApi: api,
            paymentProvidersApi: providers(),
            onEventCreated: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume draft'));
      await tester.pumpAndSettle();
      expect(find.text('Birthday'), findsOneWidget);
      await tester.tap(find.text('Create the fiestaaa'));
      await tester.pumpAndSettle();
      expect(api.created, 0);
      final search = find.byTooltip('Search');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Paris, France'));
      await tester.tap(find.text('Paris, France'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create the fiestaaa'));
      await tester.pumpAndSettle();
      expect(api.created, 1);
      expect(completed, isFalse);
      expect(await store.read('me@example.com'), isNotNull);
      api.fail = false;
      await tester.tap(find.text('Create the fiestaaa'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(await store.read('me@example.com'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('discarding a draft starts with empty fields', (tester) async {
    const store = EventDraftStore();
    await store.write('me@example.com', data.fields('Birthday'));
    await tester.pumpWidget(
      app(
        EventCreatePage(
          session: SessionData(token: 'token', email: 'me@example.com'),
          eventsApi: _Api(),
          paymentProvidersApi: providers(),
          onEventCreated: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();
    expect(find.text('Birthday'), findsNothing);
    expect(await store.read('me@example.com'), isNull);
  });
  testWidgets(
    'edit preserves input through a failed save and returns an updated result on retry',
    (tester) async {
      final api = _Api()..fail = true;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          locale: const Locale('en'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      EventEditPageResult? result;
      nav.currentState!
          .push<EventEditPageResult>(
            MaterialPageRoute(
              builder: (_) => EventEditPage(
                session: SessionData(
                  token: 'token',
                  email: 'owner@example.com',
                ),
                initialEvent: fixtures.event(),
                eventsApi: api,
                paymentProvidersApi: providers(),
              ),
            ),
          )
          .then((value) => result = value);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        '  Edited dinner  ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        api.updated,
        0,
      ); // An address without coordinates must be revalidated.
      await tester.ensureVisible(find.byTooltip('Search'));
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Paris, France'));
      await tester.tap(find.text('Paris, France'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.updated, 1);
      expect(find.text('  Edited dinner  '), findsOneWidget);
      expect(result, isNull);
      expect(api.lastPayload!.name, 'Edited dinner');
      expect(api.lastPayload!.latitude, 48.85);
      api.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.updated, 2);
      expect(result!.deleted, isFalse);
      expect(result!.event!.id, 1);
      expect(find.text('Home'), findsOneWidget);
    },
  );
  testWidgets('editing asks before discarding changes', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => EventEditPage(
          session: SessionData(token: 'token', email: 'owner@example.com'),
          initialEvent: fixtures.event(),
          eventsApi: _Api(),
          paymentProvidersApi: providers(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Changed');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Changed'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave without saving'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
