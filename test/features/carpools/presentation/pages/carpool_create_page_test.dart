import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/pages/carpool_create_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
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
  testWidgets('keeps form open when departure expires before saving', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _buildApp(
        CarpoolCreatePage(
          eventId: 1,
          eventDate: now.add(const Duration(days: 1)),
          session: SessionData(token: 'token', email: 'driver@example.com'),
          existingCarpool: CarpoolModel(
            carpoolId: 1,
            eventId: 1,
            driverId: 1,
            origin: 'Paris',
            departAt: now.subtract(const Duration(minutes: 1)),
            seatsTotal: 2,
            seatsTaken: 0,
            createdAt: now,
            updatedAt: now,
            passengers: const [],
          ),
        ),
      ),
    );
    final save = find.byType(ElevatedButton);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byType(CarpoolCreatePage), findsOneWidget);
    expect(
      find.text('Choisissez une heure de départ dans le futur.'),
      findsOneWidget,
    );
    expect(find.text('Paris'), findsOneWidget);
  });

  for (final hour in [9, 11]) {
    testWidgets('keeps selected departure visible at hour $hour', (
      tester,
    ) async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final event = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        10,
        3,
      );
      await tester.pumpWidget(
        _buildApp(
          CarpoolCreatePage(
            eventId: 1,
            eventDate: event,
            session: SessionData(token: 'token', email: 'driver@example.com'),
          ),
        ),
      );
      await tester.tap(find.text('Sélectionner une date et heure'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(event);
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(TimePickerDialog)),
      ).pop(TimeOfDay(hour: hour, minute: 0));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${hour.toString().padLeft(2, '0')}:00'),
        findsOneWidget,
      );
      final l10n = S.of(tester.element(find.byType(CarpoolCreatePage)));
      expect(
        find.text(l10n.carpoolCannotBeAfterEvent),
        hour > 10 ? findsOneWidget : findsNothing,
      );
      expect(find.text(l10n.carpoolDateTimeRequired), findsNothing);
    });
  }

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
