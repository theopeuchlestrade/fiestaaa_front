@TestOn('browser')
library;

import 'package:fiestaaa_front/src/features/events/calendar/event_calendar_entry.dart';
import 'package:fiestaaa_front/src/features/events/calendar/native_calendar_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../features/events/calendar/calendar_fixture.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  test('Web never invokes mobile calendar APIs', () async {
    const adapter = NativeCalendarAdapter();
    expect(await adapter.supportsEditor(), isFalse);
    expect(
      await adapter.openEditor(EventCalendarEntry.fromEvent(calendarEvent())),
      NativeCalendarResult.unavailable,
    );
  });
}
