import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_response.dart' as api;
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

  @override
  Future<api.Page<EventModel>> fetchEventsPage({
    required String token,
    int limit = 50,
    String? cursor,
  }) async {
    calls++;
    return cursor == null
        ? api.Page(items: [_event(1, 'First event')], nextCursor: 'next')
        : api.Page(items: [_event(2, 'Second event')]);
  }

  @override
  void dispose() {}
}

class _InvitationsApi extends InvitationsApi {
  @override
  Future<List<InvitationModel>> fetchMyInvitations(String token) async => [];

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
}
