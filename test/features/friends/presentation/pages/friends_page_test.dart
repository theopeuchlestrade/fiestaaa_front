import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FriendsApi extends FriendsApi {
  @override
  Future<List<FriendModel>> fetchFriends(String token) async => [
    FriendModel(
      email: 'alice@example.com',
      handle: 'alice',
      since: DateTime.utc(2026),
    ),
    FriendModel(
      email: 'zoe@example.com',
      handle: 'zoe',
      since: DateTime.utc(2025),
    ),
  ];

  @override
  Future<List<FriendRequestModel>> fetchRequests(String token) async => [
    FriendRequestModel(
      id: 1,
      senderEmail: 'bob@example.com',
      senderHandle: 'bob',
      receiverEmail: 'me@example.com',
      receiverHandle: 'me',
      status: 'Pending',
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  void dispose() {}
}

class _EventsApi extends EventsApi {
  @override
  Future<List<EventModel>> fetchEvents({required String token}) async => [];

  @override
  void dispose() {}
}

class _InvitationsApi extends InvitationsApi {
  @override
  Future<List<InvitationModel>> fetchEventInvitations({
    required String token,
    required int eventId,
  }) async => [];

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
  final session = SessionData(
    token: 'token',
    email: 'me@example.com',
    handle: 'me',
  );

  testWidgets('renders directory, requests and add tabs', (tester) async {
    await tester.pumpWidget(
      _app(
        FriendsPage(
          session: session,
          friendsApi: _FriendsApi(),
          eventsApi: _EventsApi(),
          invitationsApi: _InvitationsApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('alice'), findsWidgets);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining('bob'), findsWidgets);

    await tester.tap(find.byType(Tab).at(2));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('renders event invitation selection mode', (tester) async {
    await tester.pumpWidget(
      _app(
        FriendsPage(
          session: session,
          inviteFlow: const FriendsPageInviteFlow(
            eventId: 7,
            eventName: 'Picnic',
          ),
          friendsApi: _FriendsApi(),
          eventsApi: _EventsApi(),
          invitationsApi: _InvitationsApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('alice'), findsWidgets);
    expect(find.textContaining('Picnic'), findsWidgets);
  });
}
