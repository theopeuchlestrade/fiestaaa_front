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
  _Api({this.covered = false, this.contributed = false});
  final bool covered;
  final bool contributed;
  int? reserved;
  String? createdName;
  EventItemKind? createdKind;
  Object? mutationError;
  int itemReads = 0;
  bool fail = false;
  List<PollModel> polls = [];
  List<int>? submittedVotes;
  int pollReads = 0;
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
          reservedQuantity: kind == EventItemKind.need && covered ? 6 : 0,
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
  Future<EventItemModel> reserveEventItem({
    required String token,
    required int eventId,
    required int itemId,
    required int quantity,
  }) async {
    if (mutationError != null) throw mutationError!;
    reserved = quantity;
    return (await fetchEventItems(eventId, token: token)).first;
  }

  @override
  Future<EventItemModel> createCustomEventItem({
    required String token,
    required int eventId,
    required String name,
    required int maxQuantity,
    required String unitLabel,
    EventItemKind? itemKind,
  }) async {
    if (mutationError != null) throw mutationError!;
    createdName = name;
    createdKind = itemKind;
    return (await fetchEventItems(eventId, token: token)).first;
  }

  @override
  Future<List<PollModel>> fetchEventPolls({
    required String token,
    required int eventId,
  }) async {
    pollReads++;
    return polls;
  }

  @override
  Future<PollModel> votePoll({
    required String token,
    required int eventId,
    required int pollId,
    required List<int> optionIds,
  }) async {
    submittedVotes = optionIds;
    final old = polls.firstWhere((poll) => poll.id == pollId);
    final next = _poll(
      id: old.id,
      question: old.question,
      votes: optionIds,
      multiple: old.allowMultiple,
    );
    polls = [
      for (final poll in polls)
        if (poll.id == pollId) next else poll,
    ];
    return next;
  }

  @override
  Future<List<ItemContributionModel>> fetchEventItemContributions({
    required String token,
    required int eventId,
  }) async => contributed
      ? [
          ItemContributionModel(
            itemId: 1,
            quantity: 2,
            email: 'guest@example.com',
            handle: 'guest',
          ),
        ]
      : [];
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
  EventModule module = EventModule.items,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: EventDetailPage(
    module: module,
    session: SessionData(
      token: 'test',
      email: owner ? 'owner@example.com' : 'guest@example.com',
    ),
    event: fixtures.event(
      features: enabled ? [eventFeatureItems, eventFeaturePolls] : [],
    ),
    eventsApi: api,
    invitationsApi: _Invitations(status),
    realtimeClientFactory: (_, _) => _Realtime(),
    paymentProvidersApi: PaymentProvidersApi(
      client: MockClient((_) async => http.Response('[]', 200)),
    ),
  ),
);
PollModel _poll({
  int id = 1,
  String question = 'Food?',
  List<int> votes = const [],
  bool multiple = false,
  bool expired = false,
}) => PollModel(
  id: id,
  eventId: 1,
  question: question,
  allowMultiple: multiple,
  expiresAt: DateTime(2099),
  createdAt: DateTime(2026),
  createdByEmail: 'owner@example.com',
  options: [
    PollOptionModel(id: 1, label: 'Pizza', voteCount: 1, voters: []),
    PollOptionModel(id: 2, label: 'Salad', voteCount: 0, voters: []),
  ],
  myVotes: votes,
  totalVotes: 1,
  hasExpired: expired,
);
void main() {
  testWidgets(
    'contribution validates quantity and refreshes only after successful reservation',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I contribute'));
      await tester.pumpAndSettle();
      for (final value in ['', '-1', '7', 'invalid']) {
        await tester.enterText(find.byType(TextFormField), value);
        await tester.tap(find.text('Validate'));
        await tester.pumpAndSettle();
        expect(api.reserved, isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
      }
      await tester.enterText(find.byType(TextFormField), '2');
      final reads = api.itemReads;
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();
      expect(api.reserved, 2);
      expect(api.itemReads, greaterThan(reads));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  for (final error in [
    ApiException('quantity_unavailable', statusCode: 409),
    StateError('offline'),
  ]) {
    testWidgets(
      'failed contribution retains need and remains retryable: $error',
      (tester) async {
        final api = _Api()..mutationError = error;
        await tester.pumpWidget(_app(api));
        await tester.pumpAndSettle();
        await tester.tap(find.text('I contribute'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '1');
        await tester.tap(find.text('Validate'));
        await tester.pumpAndSettle();
        expect(api.reserved, isNull);
        expect(find.text('Organizer need'), findsOneWidget);
        api.mutationError = null;
        await tester.tap(find.text('I contribute'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '0');
        await tester.tap(find.text('Validate'));
        await tester.pumpAndSettle();
        expect(api.reserved, 0);
      },
    );
  }
  for (final owner in [true, false]) {
    testWidgets(
      'item creation validates name and quantity and preserves need/bring role $owner',
      (tester) async {
        final api = _Api();
        await tester.pumpWidget(_app(api, owner: owner));
        await tester.pumpAndSettle();
        if (!owner) {
          await tester.tap(find.widgetWithText(ChoiceChip, 'Personal brings'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.text(owner ? 'Add a need' : 'Add my personal bring'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add the item'));
        await tester.tap(find.text('Add the item'));
        await tester.pumpAndSettle();
        expect(api.createdName, isNull);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          '  Fictional item  ',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '0');
        await tester.tap(find.text('Add the item'));
        await tester.pumpAndSettle();
        expect(api.createdName, isNull);
        await tester.enterText(find.byType(TextFormField).at(1), '3');
        await tester.tap(find.text('Add the item'));
        await tester.pumpAndSettle();
        expect(api.createdName, 'Fictional item');
        expect(
          api.createdKind,
          owner ? EventItemKind.need : EventItemKind.bring,
        );
      },
    );
  }
  testWidgets(
    'unanswered polls precede answers and closed polls keep results accessible',
    (tester) async {
      final api = _Api()
        ..polls = [
          _poll(id: 1, question: 'Answered', votes: [1]),
          _poll(id: 2, question: 'Pending'),
          _poll(id: 3, question: 'Closed', expired: true),
        ];
      await tester.pumpWidget(_app(api, module: EventModule.polls));
      await tester.pumpAndSettle();
      final questions = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .where((text) => ['Answered', 'Pending', 'Closed'].contains(text))
          .toList();
      expect(questions, ['Pending', 'Answered', 'Closed']);
      expect(find.text('Awaiting your answer'), findsOneWidget);
      expect(find.text('Your answers'), findsOneWidget);
      await tester.ensureVisible(find.text('View results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View results'));
      await tester.pumpAndSettle();
      final closed = find
          .ancestor(of: find.text('Closed'), matching: find.byType(Card))
          .first;
      expect(
        find.descendant(of: closed, matching: find.text('Pizza')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.descendant(of: closed, matching: find.text('Pizza')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: closed, matching: find.text('Pizza')),
      );
      expect(api.submittedVotes, isNull);
    },
  );
  for (final multiple in [false, true]) {
    testWidgets(
      'immediate vote keeps single/multiple selection and deselection ($multiple)',
      (tester) async {
        final api = _Api()
          ..polls = [
            _poll(votes: [1], multiple: multiple),
          ];
        await tester.pumpWidget(_app(api, module: EventModule.polls));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salad'));
        await tester.pumpAndSettle();
        expect(api.submittedVotes, multiple ? [1, 2] : [2]);
        await tester.tap(find.text('Salad'));
        await tester.pumpAndSettle();
        expect(api.submittedVotes, multiple ? [1] : []);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'vote identities stay accessible and deletion still asks confirmation',
    (tester) async {
      final api = _Api()..polls = [_poll()];
      await tester.pumpWidget(
        _app(api, module: EventModule.polls, owner: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Who voted?'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('No votes yet.'), findsWidgets);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Poll actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Food?'), findsOneWidget);
    },
  );
  testWidgets('waiting guests never load protected polls', (tester) async {
    final api = _Api()..polls = [_poll()];
    await tester.pumpWidget(
      _app(api, module: EventModule.polls, status: 'Waiting'),
    );
    await tester.pumpAndSettle();
    expect(api.pollReads, 0);
    expect(find.text('Food?'), findsNothing);
  });
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
      expect(find.text('Add a need'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Personal brings'));
      await tester.pumpAndSettle();
      expect(find.text('Personal bring'), findsOneWidget);
      expect(find.text('Organizer need'), findsNothing);
      expect(find.text('Add my personal bring'), findsOneWidget);
    },
  );
  testWidgets(
    'A covered need keeps contribution editing only for its contributor',
    (tester) async {
      await tester.pumpWidget(_app(_Api(covered: true, contributed: true)));
      await tester.pumpAndSettle();
      expect(find.text('Need covered'), findsOneWidget);
      expect(find.textContaining('Your contribution: 2'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(_Api(covered: true)));
      await tester.pumpAndSettle();
      expect(find.text('Need covered'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );
  testWidgets('switching to personal brings resets need-only filters', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Api()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter and sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('items_scope_toCover')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Personal brings'));
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
