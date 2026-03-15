import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
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

  testWidgets('mobile layout remains stacked on narrow screens', (
    WidgetTester tester,
  ) async {
    await _pumpAuthPage(tester, const Size(390, 844));

    expect(find.byKey(const ValueKey('auth-mobile-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-desktop-card')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-mobile-card'))).width,
      closeTo(350, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet widths keep the stacked layout without stretching', (
    WidgetTester tester,
  ) async {
    await _pumpAuthPage(tester, const Size(820, 900));

    expect(find.byKey(const ValueKey('auth-mobile-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-desktop-card')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-mobile-card'))).width,
      closeTo(560, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout fills the available viewport height', (
    WidgetTester tester,
  ) async {
    await _pumpAuthPage(tester, const Size(1440, 900));

    expect(find.byKey(const ValueKey('auth-desktop-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-desktop-branding-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth-mobile-card')), findsNothing);

    final cardSize = tester.getSize(
      find.byKey(const ValueKey('auth-desktop-card')),
    );
    expect(cardSize.width, closeTo(1376, 0.1));
    expect(cardSize.height, closeTo(852, 0.1));
    expect(tester.takeException(), isNull);
  });
}
