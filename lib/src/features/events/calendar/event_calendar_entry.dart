import 'dart:convert';
import 'dart:typed_data';

import 'package:timezone/timezone.dart' as tz;

import '../domain/event_model.dart';

/// A one-time calendar snapshot. Exporting never changes the Fiestaaa event.
class EventCalendarEntry {
  EventCalendarEntry.fromEvent(EventModel event)
    : id = event.id,
      title = event.name,
      description = event.description,
      address = event.address,
      timezone = event.timezone {
    DateTime inEventZone(DateTime date, Duration time) {
      final location = tz.getLocation(event.timezone);
      return tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
        time.inHours,
        time.inMinutes.remainder(60),
        time.inSeconds.remainder(60),
      ).toUtc();
    }

    start =
        event.canonicalStartAt?.toUtc() ??
        inEventZone(event.date, event.startTime);
    // effective_end_at may be a lifecycle default rather than an explicit end.
    end = event.hasEndDateTime
        ? event.canonicalEffectiveEndAt?.toUtc() ??
              inEventZone(event.endDate!, event.endTime!)
        : start.add(const Duration(hours: 1));
    if (!end.isAfter(start)) {
      throw const FormatException('Calendar end must follow start');
    }
  }

  final int id;
  final String title;
  final String description;
  final String address;
  final String timezone;
  late final DateTime start;
  late final DateTime end;

  String get fileName => 'fiestaaa-$id.ics';

  Uri get googleUri => Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'details': description,
    'location': address,
    'dates': '${_timestamp(start)}/${_timestamp(end)}',
    'ctz': timezone,
  });

  Uint8List toIcs({DateTime? now}) {
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Fiestaaa//Event Calendar//EN',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      'UID:fiestaaa-$id@fiestaaa.app',
      'DTSTAMP:${_timestamp(now ?? DateTime.now())}',
      'DTSTART:${_timestamp(start)}',
      'DTEND:${_timestamp(end)}',
      'SUMMARY:${_escape(title)}',
      'DESCRIPTION:${_escape(description)}',
      'LOCATION:${_escape(address)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return Uint8List.fromList(
      utf8.encode('${lines.map(_fold).join('\r\n')}\r\n'),
    );
  }

  static String _timestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');

  // RFC 5545: at most 75 UTF-8 octets per physical line, including the
  // continuation space. Iterating code points never splits a UTF-8 sequence.
  static String _fold(String text) {
    final result = StringBuffer();
    var octets = 0;
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final size = utf8.encode(character).length;
      if (octets + size > 75) {
        result.write('\r\n ');
        octets = 1;
      }
      result.write(character);
      octets += size;
    }
    return result.toString();
  }
}
