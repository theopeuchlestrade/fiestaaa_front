import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/pages/carpool_create_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp(Widget child) {
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
    home: Scaffold(body: Material(child: child)),
  );
}

void main() {
  testWidgets('uses the shared modal header with a close icon', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        CarpoolCreatePage(
          eventId: 1,
          eventDate: DateTime(2030, 7, 1, 18),
          session: SessionData(
            token: 'token',
            email: 'driver@example.com',
            handle: 'driver',
          ),
        ),
      ),
    );

    expect(find.text('Proposer un covoiturage'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });
}
