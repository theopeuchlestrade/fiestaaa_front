import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_detail_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../widgets/event_personal_summary_test.dart' as fixtures;

class _Api extends EventsApi {
  int itemReads = 0;
  bool fail = false;
  @override
  Future<EventModel> fetchEventById({
    required String token,
    required int eventId,
  }) async => fixtures.event();
  @override
  Future<List<EventItemModel>> fetchEventItems(
    int eventId, {
    String? token,
    String? scope,
  }) async {
    itemReads++;
    if (fail) throw ApiException('unavailable', statusCode: 503);
    return [
      for (final kind in EventItemKind.values)
        EventItemModel(
          eventId: 1,
          itemId: kind.index + 1,
          typeId: 1,
          typeName: 'Food',
          name: kind == EventItemKind.need
              ? 'Organizer need'
              : 'Personal bring',
          maxQuantity: 6,
          reservedQuantity: 0,
          unitLabel: 'units',
          kind: kind,
          createdByEmail: kind == EventItemKind.need
              ? 'owner@example.com'
              : 'guest@example.com',
          createdByHandle: kind == EventItemKind.need ? 'owner' : 'guest',
          createdByAvatarUrl: null,
        ),
    ];
  }

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

class _Invitations extends InvitationsApi {
  _Invitations(this.status);
  final String status;
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

class _Realtime extends RealtimeClient {
  _Realtime() : super(token: 'test');
  @override
  void connect() {}
}

Widget _app(
  _Api api, {
  String status = 'Accepted',
  bool enabled = true,
  bool owner = false,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: EventDetailPage(
    module: EventModule.items,
    session: SessionData(
      token: 'test',
      email: owner ? 'owner@example.com' : 'guest@example.com',
    ),
    event: fixtures.event(features: enabled ? [eventFeatureItems] : []),
    eventsApi: api,
    invitationsApi: _Invitations(status),
    realtimeClientFactory: (_, _) => _Realtime(),
    paymentProvidersApi: PaymentProvidersApi(
      client: MockClient((_) async => http.Response('[]', 200)),
    ),
  ),
);
void main() {
  testWidgets('waiting guests do not load protected item content', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, status: 'Waiting'));
    await tester.pumpAndSettle();
    expect(api.itemReads, 0);
    expect(find.text('Organizer need'), findsNothing);
    expect(
      find.text('Accept the invitation to access this module.'),
      findsOneWidget,
    );
  });
  testWidgets('disabled modules remain inaccessible even for owner', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, enabled: false, owner: true));
    await tester.pumpAndSettle();
    expect(api.itemReads, 0);
    expect(find.text('This module is disabled.'), findsOneWidget);
  });
  testWidgets(
    'accepted participants switch between needs and personal brings',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(find.text('Organizer need'), findsOneWidget);
      expect(find.text('Personal bring'), findsNothing);
      expect(find.text('Add'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'What we bring'));
      await tester.pumpAndSettle();
      expect(find.text('Personal bring'), findsOneWidget);
      expect(find.text('Organizer need'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
    },
  );
  testWidgets('switching to personal brings resets need-only filters', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Api()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('items_scope_toCover')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'What we bring'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('items_scope_toCover')), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('items_scope_all')))
          .selected,
      isTrue,
    );
    expect(find.text('Personal bring'), findsOneWidget);
  });
  testWidgets('failed refresh retains loaded module content', (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    api.fail = true;
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Organizer need'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
