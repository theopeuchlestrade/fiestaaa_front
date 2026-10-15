import 'dart:convert';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_calendar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../../calendar/calendar_fixture.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  Widget app({
    String language = 'en',
    Future<bool> Function(Uri)? open,
    Future<void> Function(Uint8List, String, Rect)? export,
  }) => MaterialApp(
    locale: Locale(language),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: EventCalendarCard(
        event: calendarEvent(),
        schedule: '14 July 2026 · 20:30',
        openGoogle: open,
        exportFile: export,
      ),
    ),
  );

  Future<void> pick(WidgetTester tester, String provider) async {
    await tester.tap(find.text('14 July 2026 · 20:30'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(provider));
    await tester.tap(find.text(provider));
    await tester.pumpAndSettle();
  }

  testWidgets('the schedule opens all providers and dismissal has no effects', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        open: (_) async {
          calls++;
          return true;
        },
        export: (_, _, _) async {
          calls++;
        },
      ),
    );
    await tester.tap(find.text('14 July 2026 · 20:30'));
    await tester.pumpAndSettle();
    for (final label in [
      'Google Calendar',
      'Apple Calendar',
      'Proton Calendar',
      'Other calendar',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Import/export'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Google Calendar'), findsNothing);
    expect(calls, 0);
  });

  testWidgets('Google opens a draft and offers ICS on failure', (tester) async {
    Uri? opened;
    String? exported;
    await tester.pumpWidget(
      app(
        open: (uri) async {
          opened = uri;
          return false;
        },
        export: (bytes, name, origin) async {
          exported = utf8.decode(bytes);
          expect(name, 'fiestaaa-42.ics');
          expect(origin.isEmpty, isFalse);
        },
      ),
    );
    await pick(tester, 'Google Calendar');
    expect(opened!.queryParameters['text'], 'Fête 🎉');
    expect(
      find.text('Unable to open the calendar or export the file.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Export .ics'));
    await tester.pumpAndSettle();
    expect(exported, contains('BEGIN:VEVENT'));
  });

  for (final provider in [
    'Apple Calendar',
    'Proton Calendar',
    'Other calendar',
  ]) {
    testWidgets('$provider exports ICS without opening Google', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        app(
          open: (_) async => fail('Must not open Google'),
          export: (bytes, name, origin) async {
            calls++;
            expect(utf8.decode(bytes), contains('DTSTART:20260714T183000Z'));
          },
        ),
      );
      await pick(tester, provider);
      expect(calls, 1);
      expect(
        find.text('Unable to open the calendar or export the file.'),
        findsNothing,
      );
    });
  }

  testWidgets('failed export can be retried', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        export: (_, _, _) async {
          if (++calls == 1) throw StateError('export failed');
        },
      ),
    );
    await pick(tester, 'Other calendar');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('card supports keyboard activation and exposes its action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    expect(find.bySemanticsLabel(RegExp('Add to my calendar')), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Google Calendar'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('French labels and instructions are available', (tester) async {
    await tester.pumpWidget(app(language: 'fr'));
    expect(find.text('Ajouter à mon agenda'), findsOneWidget);
    await tester.tap(find.text('Ajouter à mon agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Autre agenda'), findsOneWidget);
    expect(find.textContaining('Importer/exporter'), findsOneWidget);
  });
}
