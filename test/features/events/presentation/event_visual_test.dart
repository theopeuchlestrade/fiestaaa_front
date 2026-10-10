import 'dart:convert';
import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:fiestaaa_front/src/features/beta_api.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_expenses_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_invitations_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_edit_page.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_expense_model.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/pages/event_carpools_page.dart';
import 'package:fiestaaa_front/src/features/carpools/data/carpools_api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'dart:io' show Platform;
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_response.dart' as response;
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/events_list_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_create_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_detail_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'widgets/event_personal_summary_test.dart' as fixtures;

class _Api extends EventsApi {
  @override
  Future<response.Page<EventModel>> fetchEventsPage({
    required String token,
    int limit = 50,
    String? cursor,
    String? query,
    String? view,
    String? sort,
  }) async => response.Page(items: [fixtures.event()]);
  @override
  Future<List<EventItemModel>> fetchEventItems(
    int eventId, {
    String? token,
    String? scope,
  }) async => [
    EventItemModel(
      eventId: 1,
      itemId: 1,
      typeId: 1,
      typeName: 'Drinks',
      name: 'Soft drinks',
      maxQuantity: 6,
      reservedQuantity: 2,
      unitLabel: 'bottles',
      kind: EventItemKind.need,
      createdByEmail: 'owner@example.com',
      createdByHandle: 'demo',
      createdByAvatarUrl: null,
    ),
  ];
  @override
  Future<List<ItemContributionModel>> fetchEventItemContributions({
    required String token,
    required int eventId,
  }) async => [];
  @override
  Future<List<PollModel>> fetchEventPolls({
    required String token,
    required int eventId,
  }) async => [];
  @override
  Future<List<EventExpenseModel>> fetchEventExpenses({
    required String token,
    required int eventId,
  }) async => [];
  @override
  Future<EventExpensesSummaryModel> fetchEventExpensesSummary({
    required String token,
    required int eventId,
  }) async => EventExpensesSummaryModel(
    currency: 'EUR',
    totalExpensesCents: 0,
    balances: [],
    settlements: [],
  );
  @override
  void dispose() {}
}

class _ProfileApi extends ProfileApi {
  @override
  Future<ProfileInfo> fetchProfile(String token) async => ProfileInfo(
    email: 'demo@example.invalid',
    handle: 'demo',
    expiration: DateTime(2099),
  );
  @override
  void dispose() {}
}

class _Realtime extends RealtimeClient {
  _Realtime() : super(token: 'test');
  @override
  void connect() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> legalPages;
  setUpAll(() async {
    tz.initializeTimeZones();
    legalPages =
        jsonDecode(await rootBundle.loadString('assets/legal/pages.json'))
            as Map<String, dynamic>;
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  const referenceScreens = [
    'list',
    'form',
    'detail',
    'needs',
    'profile',
    'auth',
  ];
  for (final screen in [
    ...referenceScreens,
    'edit',
    'polls',
    'expenses',
    'carpools',
    'participants',
    'friends',
    'recovery',
    'safety',
    'privacy',
    'terms',
    'support',
    'delete-account',
  ]) {
    for (final width in [360.0, 720.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          for (final locale in ['en', 'fr']) {
            testWidgets(
              '$screen ${width.toInt()} scale $scale ${dark ? 'dark' : 'light'} $locale',
              (tester) async {
                SharedPreferences.setMockInitialValues({});
                tester.view.physicalSize = Size(width, 1000);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                PackageInfo.setMockInitialValues(
                  appName: 'Fiestaaa',
                  packageName: 'com.fiestaaa.fiestaaa',
                  version: '0.5.0',
                  buildNumber: '5027',
                  buildSignature: 'test',
                );
                final api = _Api();
                final friendsApi = FriendsApi(
                  client: MockClient((_) async => http.Response('[]', 200)),
                );
                final invitations = InvitationsApi(
                  client: MockClient((_) async => http.Response('[]', 200)),
                );
                final providers = PaymentProvidersApi(
                  client: MockClient((_) async => http.Response('[]', 200)),
                );
                final session = SessionData(
                  token: 'test',
                  email: 'owner@example.com',
                );
                final child = switch (screen) {
                  'list' => EventsListPage(
                    session: session,
                    eventsApi: api,
                    invitationsApi: invitations,
                    onEventSelected: (_) async {},
                    onOpenTrash: () {},
                    onCreate: () {},
                  ),
                  'form' => EventCreatePage(
                    initialDateTime: DateTime(2099, 7, 1, 20),
                    session: session,
                    eventsApi: api,
                    paymentProvidersApi: providers,
                    onEventCreated: () {},
                  ),
                  'auth' => AuthPage(onAuthenticated: (_) async {}),
                  'edit' => EventEditPage(
                    session: session,
                    initialEvent: fixtures.event(),
                    eventsApi: api,
                    paymentProvidersApi: providers,
                  ),
                  'expenses' => EventExpensesPage(
                    eventId: 1,
                    eventName: 'Dinner',
                    ownerEmail: session.email,
                    session: session,
                    isOwner: true,
                    hasAcceptedInvitation: false,
                    isReadOnly: false,
                    eventsApi: api,
                    invitationsApi: invitations,
                  ),
                  'participants' => EventInvitationsPage(
                    session: session,
                    eventId: 1,
                    eventName: 'Dinner',
                    ownerEmail: session.email,
                    eventReadOnly: false,
                    invitationsApi: invitations,
                    friendsApi: friendsApi,
                  ),
                  'carpools' => EventCarpoolsPage(
                    eventId: 1,
                    eventName: 'Dinner',
                    eventDate: DateTime(2099),
                    session: session,
                    isOwner: true,
                    hasAcceptedInvitation: false,
                    eventReadOnly: false,
                    realtimeStream: const Stream<Map<String, dynamic>>.empty(),
                    api: CarpoolsApi(
                      client: MockClient((_) async => http.Response('[]', 200)),
                    ),
                  ),
                  'friends' => FriendsPage(
                    session: session,
                    friendsApi: friendsApi,
                    eventsApi: api,
                    invitationsApi: invitations,
                  ),
                  'recovery' => const PasswordResetPage(),
                  'safety' => SafetyPage(
                    token: 'test',
                    api: BetaApi(
                      client: MockClient((_) async => http.Response('[]', 200)),
                    ),
                  ),
                  'privacy' || 'terms' || 'support' || 'delete-account' =>
                    LegalPage(page: screen, pages: Future.value(legalPages)),
                  'profile' => ProfilePage(
                    session: session,
                    onLogout: () {},
                    api: _ProfileApi(),
                    themeService: ThemeService(),
                    localeService: LocaleService(),
                  ),
                  _ => EventDetailPage(
                    module: screen == 'needs'
                        ? EventModule.items
                        : screen == 'polls'
                        ? EventModule.polls
                        : null,
                    session: session,
                    event: fixtures.event(),
                    eventsApi: api,
                    invitationsApi: invitations,
                    paymentProvidersApi: providers,
                    realtimeClientFactory: (_, _) => _Realtime(),
                  ),
                };
                await tester.pumpWidget(
                  MaterialApp(
                    locale: Locale(locale),
                    localizationsDelegates: S.localizationsDelegates,
                    supportedLocales: S.supportedLocales,
                    theme: dark
                        ? buildFiestaaaDarkTheme()
                        : buildFiestaaaTheme(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: RepaintBoundary(
                        key: const ValueKey('screen'),
                        child: child,
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                final golden =
                    referenceScreens.contains(screen) &&
                    scale == 1 &&
                    ((width == 360 && !dark && locale == 'en') ||
                        (width == 1440 && dark && locale == 'fr'));
                if (golden) {
                  Object? comparisonFailure;
                  StackTrace? comparisonStack;
                  // Produce comparison artifacts even if a later accessibility check fails.
                  try {
                    await expectLater(
                      find.byKey(const ValueKey('screen')),
                      matchesGoldenFile(
                        'goldens/${Platform.operatingSystem}/${screen}_${width.toInt()}_${dark ? 'dark' : 'light'}_$locale.png',
                      ),
                    );
                  } catch (error, stack) {
                    comparisonFailure = error;
                    comparisonStack = stack;
                  }
                  final semantics = tester.ensureSemantics();
                  await tester.pump();
                  try {
                    if (screen == 'needs') {
                      // A progress role must not absorb the surrounding controls.
                      final progress = tester.getSemantics(
                        find.byType(LinearProgressIndicator),
                      );
                      expect(progress.getSemanticsData().label, isEmpty);
                    }
                    await expectLater(
                      tester,
                      meetsGuideline(labeledTapTargetGuideline),
                    );
                    await expectLater(
                      tester,
                      meetsGuideline(androidTapTargetGuideline),
                    );
                    await expectLater(
                      tester,
                      meetsGuideline(textContrastGuideline),
                    );
                  } finally {
                    semantics.dispose();
                  }
                  if (comparisonFailure != null) {
                    Error.throwWithStackTrace(
                      comparisonFailure,
                      comparisonStack!,
                    );
                  }
                }
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pumpAndSettle();
                invitations.dispose();
                providers.dispose();
              },
            );
          }
        }
      }
    }
  }
}
