import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_expense_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_expenses_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends EventsApi {
  int balance = 1200;
  bool fail = false;
  bool deleted = false;
  @override
  Future<List<EventExpenseModel>> fetchEventExpenses({
    required String token,
    required int eventId,
  }) async {
    if (fail) throw ApiException('unavailable', statusCode: 503);
    return [
      EventExpenseModel(
        id: 1,
        eventId: 1,
        paidByUserId: 1,
        paidByHandle: 'owner',
        paidByAvatarUrl: null,
        title: 'Groceries',
        amountCents: 2400,
        note: 'Meet at the station',
        expenseDate: DateTime(2099),
        createdAt: DateTime(2099),
        participants: [
          EventExpenseParticipantModel(
            userId: 2,
            handle: 'guest',
            avatarUrl: null,
          ),
        ],
      ),
    ];
  }

  @override
  Future<EventExpensesSummaryModel> fetchEventExpensesSummary({
    required String token,
    required int eventId,
  }) async => EventExpensesSummaryModel(
    currency: 'EUR',
    totalExpensesCents: 2400,
    balances: [
      EventExpenseBalanceModel(
        userId: 1,
        handle: 'owner',
        avatarUrl: null,
        paidCents: 2400,
        owedCents: 1200,
        balanceCents: balance,
      ),
    ],
    settlements: balance == 0
        ? []
        : [
            EventExpenseSettlementModel(
              fromUserId: 2,
              fromHandle: 'guest',
              toUserId: 1,
              toHandle: 'owner',
              amountCents: 1200,
            ),
          ],
  );
  @override
  Future<void> deleteEventExpense({
    required String token,
    required int eventId,
    required int expenseId,
  }) async {
    deleted = true;
  }

  @override
  void dispose() {}
}

class _Invitations extends InvitationsApi {
  @override
  Future<List<InvitationModel>> fetchEventInvitations({
    required String token,
    required int eventId,
  }) async => [
    InvitationModel(
      eventId: 1,
      userId: 1,
      email: 'owner@example.invalid',
      handle: 'owner',
      status: 'Accepted',
      dateInvi: DateTime(2026),
    ),
  ];
  @override
  void dispose() {}
}

Widget _app(
  _Api api, {
  bool readonly = false,
  bool owner = true,
  double textScale = 1,
  Stream<Map<String, dynamic>>? stream,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: EventExpensesPage(
    eventId: 1,
    eventName: 'Dinner',
    ownerEmail: 'owner@example.invalid',
    session: SessionData(
      token: 'test',
      email: owner ? 'owner@example.invalid' : 'guest@example.invalid',
    ),
    isOwner: owner,
    hasAcceptedInvitation: true,
    isReadOnly: readonly,
    eventsApi: api,
    invitationsApi: _Invitations(),
    realtimeStream: stream,
  ),
);
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'expanded balances and repayment details fit narrow enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_Api(), textScale: 2));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Participant balances'));
      await tester.scrollUntilVisible(find.text('Who repays whom?'), 200);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Who repays whom?'));
      expect(find.textContaining('guest repays'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('zero balance does not claim a positive repayment', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Api()..balance = 0));
    await tester.pumpAndSettle();
    expect(find.text('No repayment needed'), findsOneWidget);
    await tapVisible(tester, find.text('Who repays whom?'));
    expect(
      find.textContaining('Payments take place outside Fiestaaa'),
      findsOneWidget,
    );
  });
  testWidgets(
    'participant balances, suggested repayments and expense details are distinct',
    (tester) async {
      await tester.pumpWidget(_app(_Api()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Who repays whom?'));
      expect(find.textContaining('guest repays'), findsOneWidget);
      await tapVisible(tester, find.text('Participant balances'));
      expect(find.textContaining('Paid:'), findsWidgets);
      await tapVisible(tester, find.text('Details and participants'));
      expect(find.text('Meet at the station'), findsOneWidget);
      expect(find.textContaining('guest'), findsWidgets);
    },
  );
  testWidgets('delete menu preserves confirmation and cancel', (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Expense actions'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deleted, isFalse);
    expect(find.text('Groceries'), findsOneWidget);
  });
  testWidgets('read only and non payer views hide disallowed actions', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Api(), readonly: true));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byTooltip('Expense actions'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(_Api(), owner: false));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expense actions'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });
  testWidgets('failed realtime refresh preserves ledger and back navigation', (
    tester,
  ) async {
    final api = _Api();
    final messages = StreamController<Map<String, dynamic>>.broadcast();
    await tester.pumpWidget(_app(api, stream: messages.stream));
    await tester.pumpAndSettle();
    api.fail = true;
    messages.add({'type': 'event_expenses_changed', 'event_id': 1});
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Groceries'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await messages.close();
  });
}
