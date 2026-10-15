import 'package:fiestaaa_front/src/features/events/calendar/event_calendar_entry.dart';
import 'package:fiestaaa_front/src/features/events/calendar/native_calendar_adapter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'calendar_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz.initializeTimeZones);
  const channel = MethodChannel('fiestaaa/calendar');
  const adapter = NativeCalendarAdapter();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets(
    'iOS version support is determined by native capability',
    (tester) async {
      for (final supported in [false, true]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'isSupported');
          return supported;
        });
        expect(await adapter.supportsEditor(), supported);
      }
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'passes exact event data and preserves native outcomes',
    (tester) async {
      final entry = EventCalendarEntry.fromEvent(calendarEvent());
      for (final result in NativeCalendarResult.values) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openEditor');
          expect(call.arguments, {
            'title': entry.title,
            'description': entry.description,
            'location': entry.address,
            'startMillis': DateTime.utc(
              2026,
              7,
              14,
              18,
              30,
            ).millisecondsSinceEpoch,
            'endMillis': DateTime.utc(
              2026,
              7,
              14,
              19,
              30,
            ).millisecondsSinceEpoch,
            'timeZone': 'Europe/Paris',
          });
          return result.name;
        });
        expect(await adapter.openEditor(entry), result);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'missing bridge and platform failures are unavailable',
    (tester) async {
      final entry = EventCalendarEntry.fromEvent(calendarEvent());
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException(),
      );
      expect(await adapter.supportsEditor(), isFalse);
      expect(await adapter.openEditor(entry), NativeCalendarResult.unavailable);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(await adapter.supportsEditor(), isFalse);
      expect(await adapter.openEditor(entry), NativeCalendarResult.unavailable);
      messenger.setMockMethodCallHandler(channel, (_) async => 'unexpected');
      expect(await adapter.openEditor(entry), NativeCalendarResult.unavailable);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'desktop never invokes a mobile bridge',
    (tester) async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('Must not invoke native bridge'),
      );
      expect(await adapter.supportsEditor(), isFalse);
      expect(
        await adapter.openEditor(EventCalendarEntry.fromEvent(calendarEvent())),
        NativeCalendarResult.unavailable,
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );
}
