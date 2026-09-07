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
  }) async => [];
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
  void dispose() {}
}

class _Realtime extends RealtimeClient {
  _Realtime() : super(token: 'test');
  @override
  void connect() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final screen in ['list', 'form', 'detail']) {
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
                final api = _Api();
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
                  ),
                  'form' => EventCreatePage(
                    initialDateTime: DateTime(2099, 7, 1, 20),
                    session: session,
                    eventsApi: api,
                    paymentProvidersApi: providers,
                    onEventCreated: () {},
                  ),
                  _ => EventDetailPage(
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
                    scale == 1 &&
                    ((width == 360 && !dark && locale == 'en') ||
                        (width == 1440 && dark && locale == 'fr'));
                if (golden) {
                  final semantics = tester.ensureSemantics();
                  await tester.pump();
                  await expectLater(
                    tester,
                    meetsGuideline(labeledTapTargetGuideline),
                  );
                  await expectLater(
                    tester,
                    meetsGuideline(androidTapTargetGuideline),
                  );
                  semantics.dispose();
                  await expectLater(
                    find.byKey(const ValueKey('screen')),
                    matchesGoldenFile(
                      'goldens/${screen}_${width.toInt()}_${dark ? 'dark' : 'light'}_$locale.png',
                    ),
                  );
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
