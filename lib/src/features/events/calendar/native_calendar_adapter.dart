import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'event_calendar_entry.dart';

/// Android only confirms handoff; iOS can also report save or cancellation.
enum NativeCalendarResult { opened, saved, cancelled, unavailable }

class NativeCalendarAdapter {
  const NativeCalendarAdapter();

  static const _channel = MethodChannel('fiestaaa/calendar');

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<bool> supportsEditor() async {
    if (!_isMobile) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<NativeCalendarResult> openEditor(EventCalendarEntry entry) async {
    if (!_isMobile) return NativeCalendarResult.unavailable;
    try {
      final result = await _channel.invokeMethod<String>('openEditor', {
        'title': entry.title,
        'description': entry.description,
        'location': entry.address,
        'startMillis': entry.start.millisecondsSinceEpoch,
        'endMillis': entry.end.millisecondsSinceEpoch,
        'timeZone': entry.timezone,
      });
      return switch (result) {
        'opened' => NativeCalendarResult.opened,
        'saved' => NativeCalendarResult.saved,
        'cancelled' => NativeCalendarResult.cancelled,
        _ => NativeCalendarResult.unavailable,
      };
    } on MissingPluginException {
      return NativeCalendarResult.unavailable;
    } on PlatformException {
      return NativeCalendarResult.unavailable;
    }
  }
}
