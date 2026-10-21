import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp() {
  return MaterialApp(
    locale: const Locale('fr'),
    theme: buildFiestaaaTheme(),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr'), Locale('en')],
    home: AuthPage(onAuthenticated: _onAuthenticated),
  );
}

Future<void> _onAuthenticated(SessionData session) async {}

Future<void> _pumpAuthPage(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(_buildApp());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dark in [false, true]) {
    testWidgets(
      'iOS provider controls remain readable at enlarged text / $dark',
      (tester) async {
        // Retain mobile width and 200% text, but expose the whole scrollable
        // form so clipped edge semantics do not masquerade as small targets.
        tester.view.physicalSize = const Size(360, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            theme: dark ? buildFiestaaaDarkTheme() : buildFiestaaaTheme(),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: AuthPage(onAuthenticated: _onAuthenticated),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(SignInWithAppleButton));
        await tester.pumpAndSettle();
        expect(find.text('Continuer avec Apple'), findsOneWidget);
        expect(tester.getSize(find.byType(SignInWithAppleButton)).height, 96);
        expect(
          tester
              .widget<SignInWithAppleButton>(find.byType(SignInWithAppleButton))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  for (final width in [360.0, 720.0, 1024.0, 1440.0]) {
    testWidgets('shared auth form fits $width', (tester) async {
      await _pumpAuthPage(tester, Size(width, 1000));
      expect(find.byKey(const ValueKey('auth-card')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('auth-card'))).width,
        lessThanOrEqualTo(760),
      );
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
