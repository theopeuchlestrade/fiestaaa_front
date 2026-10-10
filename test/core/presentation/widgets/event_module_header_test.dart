import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/event_module_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('switching modules preserves return to the event overview', (
    tester,
  ) async {
    final reflects = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    addTearDown(() => GoRouter.optionURLReflectsImperativeAPIs = reflects);
    final router = GoRouter(
      initialLocation: '/events/1',
      routes: [
        GoRoute(
          path: '/events/1',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/events/1/items'),
              child: const Text('Open items'),
            ),
          ),
        ),
        for (final name in ['items', 'polls'])
          GoRoute(
            path: '/events/1/$name',
            builder: (_, _) => Scaffold(
              body: EventModuleHeader(
                title: name,
                eventName: 'Test event',
                eventId: 1,
                locations: const {'Polls': '/events/1/polls'},
              ),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open items'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Event modules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polls'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/events/1/polls');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open items'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/events/1');
  });
}
