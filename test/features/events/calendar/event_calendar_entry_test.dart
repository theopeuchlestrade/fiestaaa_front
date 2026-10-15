import 'dart:convert';

import 'package:fiestaaa_front/src/features/events/calendar/event_calendar_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as zones;

import 'calendar_fixture.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  test(
    'uses event zone regardless of the device zone and defaults to one hour',
    () {
      zones.setLocalLocation(zones.getLocation('Asia/Tokyo'));
      addTearDown(() => zones.setLocalLocation(zones.UTC));
      final entry = EventCalendarEntry.fromEvent(
        calendarEvent({'effective_end_at': '2026-07-15T22:00:00Z'}),
      );
      expect(entry.start, DateTime.utc(2026, 7, 14, 18, 30));
      expect(entry.end.difference(entry.start), const Duration(hours: 1));
    },
  );

  test('canonical start takes precedence over ambiguous wall time', () {
    final entry = EventCalendarEntry.fromEvent(
      calendarEvent({
        'date_event': '2026-10-25',
        'start_time': '02:30:00',
        'start_at': '2026-10-25T01:30:00Z',
      }),
    );
    expect(entry.start, DateTime.utc(2026, 10, 25, 1, 30));
    expect(entry.end, DateTime.utc(2026, 10, 25, 2, 30));
  });

  test('explicit canonical end resolves the repeated DST hour', () {
    final entry = EventCalendarEntry.fromEvent(
      calendarEvent({
        'date_event': '2026-10-25',
        'start_time': '01:30:00',
        'start_at': '2026-10-24T23:30:00Z',
        'end_date': '2026-10-25',
        'end_time': '02:30:00',
        'effective_end_at': '2026-10-25T01:30:00Z',
      }),
    );
    expect(entry.end, DateTime.utc(2026, 10, 25, 1, 30));
    expect(entry.end.difference(entry.start), const Duration(hours: 2));
  });

  test('explicit multiday end follows the event zone', () {
    final entry = EventCalendarEntry.fromEvent(
      calendarEvent({
        'timezone': 'America/New_York',
        'end_date': '2026-07-16',
        'end_time': '01:00:00',
      }),
    );
    expect(entry.start, DateTime.utc(2026, 7, 15, 0, 30));
    expect(entry.end, DateTime.utc(2026, 7, 16, 5));
  });

  for (final change in [
    (
      '2026-03-29',
      DateTime.utc(2026, 3, 29, 0, 30),
      DateTime.utc(2026, 3, 29, 1, 30),
    ),
    (
      '2026-10-25',
      DateTime.utc(2026, 10, 24, 23, 30),
      DateTime.utc(2026, 10, 25, 2, 30),
    ),
  ]) {
    test('resolves both ends across DST on ${change.$1}', () {
      final entry = EventCalendarEntry.fromEvent(
        calendarEvent({
          'date_event': change.$1,
          'start_time': '01:30:00',
          'end_date': change.$1,
          'end_time': '03:30:00',
        }),
      );
      expect(entry.start, change.$2);
      expect(entry.end, change.$3);
    });
  }

  test(
    'rejects invalid range and unknown zone rather than using device time',
    () {
      expect(
        () => EventCalendarEntry.fromEvent(
          calendarEvent({'end_date': '2026-07-14', 'end_time': '19:00:00'}),
        ),
        throwsFormatException,
      );
      expect(
        () => EventCalendarEntry.fromEvent(
          calendarEvent({'timezone': 'Unknown/Zone'}),
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'Google and ICS preserve the same event and escape reserved characters',
    () {
      const title = 'Fête 🎉, amis; café & thé';
      const description = 'Ligne 1\r\nLigne 2\\suite; oui, non\nEND:VEVENT';
      final entry = EventCalendarEntry.fromEvent(
        calendarEvent({'name_event': title, 'description': description}),
      );
      final uri = entry.googleUri;
      expect(uri.scheme, 'https');
      expect(uri.queryParameters['text'], title);
      expect(uri.queryParameters['details'], description);
      expect(uri.queryParameters['location'], entry.address);
      expect(uri.queryParameters['dates'], '20260714T183000Z/20260714T193000Z');
      expect(uri.queryParameters['ctz'], 'Europe/Paris');
      final ics = utf8
          .decode(entry.toIcs(now: DateTime.utc(2026, 1, 1)))
          .replaceAll('\r\n ', '');
      expect(ics, contains('SUMMARY:Fête 🎉\\, amis\\; café & thé\r\n'));
      expect(
        ics,
        contains(
          r'DESCRIPTION:Ligne 1\nLigne 2\\suite\; oui\, non\nEND:VEVENT',
        ),
      );
      expect(ics, contains('LOCATION:10 rue de la Paix\\, Paris\r\n'));
      expect(ics, contains('DTSTART:20260714T183000Z\r\n'));
      expect(ics, contains('DTEND:20260714T193000Z\r\n'));
      expect(ics, contains('DTSTAMP:20260101T000000Z\r\n'));
      expect(ics, contains('UID:fiestaaa-42@fiestaaa.app\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(entry.fileName, 'fiestaaa-42.ics');
    },
  );

  test(
    'folds long Unicode lines within 75 octets without splitting characters',
    () {
      final title = List.filled(80, 'é🎉').join();
      final entry = EventCalendarEntry.fromEvent(
        calendarEvent({'name_event': title}),
      );
      final raw = utf8.decode(entry.toIcs());
      for (final line in raw.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(raw.replaceAll('\r\n ', ''), contains('SUMMARY:$title\r\n'));
      expect(raw.replaceAll('\r\n', ''), isNot(contains('\n')));
    },
  );
}
