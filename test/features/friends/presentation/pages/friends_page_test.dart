import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Fiestaaa',
      packageName: 'com.fiestaaa.fiestaaa',
      version: '0.5.0',
      buildNumber: '5016',
      buildSignature: '',
    );
  });
  final session = SessionData(
    token: 'token',
    email: 'me@example.com',
    handle: 'me',
  );

  testWidgets('notification updates the cached friends page request serial', (
    tester,
  ) async {
    Widget home(int serial) => _app(
      HomePage(
        session: session,
        onLogout: () async {},
        destination: HomeDestination.friends,
        notificationIntent: const PushNotificationIntent(
          type: 'friend_request',
        ),
        notificationIntentSerial: serial,
      ),
    );
    await tester.pumpWidget(home(0));
    await tester.pump();
    expect(
      tester.widget<FriendsPage>(find.byType(FriendsPage)).requestsOpenSerial,
      0,
    );
    await tester.pumpWidget(home(1));
    await tester.pump();
    expect(
      tester.widget<FriendsPage>(find.byType(FriendsPage)).requestsOpenSerial,
      1,
    );
    await tester.pump();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await tester.pumpWidget(home(2));
    await tester.pump();
    expect(
      tester.widget<FriendsPage>(find.byType(FriendsPage)).requestsOpenSerial,
      2,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('renders friends and requests with a dedicated add action', (
    tester,
  ) async {
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

    await tester.tap(find.widgetWithText(FilledButton, 'Add friend'));
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
