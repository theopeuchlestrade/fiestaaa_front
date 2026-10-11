import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_invitations_page.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Friends extends FriendsApi {
  @override
  Future<List<FriendModel>> fetchFriends(String token) async => [];
  @override
  Future<List<FriendRequestModel>> fetchRequests(String token) async => [];
  @override
  void dispose() {}
}

class _Invitations extends InvitationsApi {
  bool empty = false;
  int? removed;
  @override
  Future<List<InvitationModel>> fetchEventInvitations({
    required String token,
    required int eventId,
  }) async => empty
      ? []
      : [
          for (final row in [
            ('owner', 'Accepted'),
            ('guest', 'Accepted'),
            ('pending', 'Waiting'),
            ('declined', 'Declined'),
          ])
            InvitationModel(
              invitationId: row.$1 == 'guest' ? 2 : 1,
              eventId: 1,
              email: '${row.$1}@example.invalid',
              handle: row.$1,
              status: row.$2,
              dateInvi: DateTime(2026),
            ),
        ];
  @override
  Future<void> deleteInvitation({
    required String token,
    required int eventId,
    required String email,
    int? invitationId,
  }) async {
    removed = invitationId;
  }

  @override
  void dispose() {}
}

Widget _app(_Invitations api, {bool owner = true, bool readonly = false}) =>
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: EventInvitationsPage(
        session: SessionData(
          token: 'test',
          email: owner ? 'owner@example.invalid' : 'guest@example.invalid',
        ),
        eventId: 1,
        eventName: 'Dinner',
        ownerEmail: 'owner@example.invalid',
        eventReadOnly: readonly,
        invitationsApi: api,
        friendsApi: _Friends(),
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
    'confirmed precede waiting and declined identities expand without duplicate count',
    (tester) async {
      await tester.pumpWidget(_app(_Invitations()));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Confirmed · 2')).dy,
        lessThan(tester.getTopLeft(find.text('Awaiting a response · 1')).dy),
      );
      expect(find.text('@declined'), findsNothing);
      await tapVisible(tester, find.byType(ExpansionTile));
      expect(find.text('@declined'), findsOneWidget);
      expect(find.text('Declined invitations · 1'), findsNothing);
    },
  );
  testWidgets(
    'invitation form is revealed on demand and retains hidden input',
    (tester) async {
      await tester.pumpWidget(_app(_Invitations()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'newguest');
      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'newguest',
      );
    },
  );
  for (final readonly in [false, true]) {
    testWidgets('nonowner/read only hides invitation mutation ($readonly)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_Invitations(), owner: readonly, readonly: readonly),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invite someone'), findsNothing);
      await tapVisible(tester, find.byTooltip('Participant actions').first);
      expect(find.text('Remove invitation'), findsNothing);
    });
  }
  testWidgets(
    'owner removal keeps the invitation identifier and protects owner',
    (tester) async {
      final api = _Invitations();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      final guest = find.ancestor(
        of: find.text('@guest'),
        matching: find.byType(ListTile),
      );
      await tapVisible(
        tester,
        find.descendant(
          of: guest,
          matching: find.byTooltip('Participant actions'),
        ),
      );
      await tester.tap(find.text('Remove invitation'));
      await tester.pumpAndSettle();
      expect(api.removed, 2);
      final owner = find.ancestor(
        of: find.text('@owner'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
          of: owner,
          matching: find.byTooltip('Participant actions'),
        ),
        findsNothing,
      );
    },
  );
}
