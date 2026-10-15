import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../calendar/calendar_file_export_native.dart'
    if (dart.library.js_interop) '../../calendar/calendar_file_export_web.dart';
import '../../calendar/event_calendar_entry.dart';
import '../../calendar/native_calendar_adapter.dart';
import '../../domain/event_model.dart';

enum _CalendarProvider { native, google, ics }

class EventCalendarCard extends StatefulWidget {
  const EventCalendarCard({
    super.key,
    required this.event,
    required this.schedule,
    this.openGoogle,
    this.exportFile,
    this.nativeCalendar = const NativeCalendarAdapter(),
  });

  final NativeCalendarAdapter nativeCalendar;
  final EventModel event;
  final String schedule;
  final Future<bool> Function(Uri uri)? openGoogle;
  final Future<void> Function(Uint8List bytes, String name, Rect origin)?
  exportFile;

  @override
  State<EventCalendarCard> createState() => _EventCalendarCardState();
}

class _EventCalendarCardState extends State<EventCalendarCard> {
  bool _busy = false;
  bool _choosing = false;

  Future<void> _pickCalendar() async {
    if (_busy || _choosing) return;
    _choosing = true;
    try {
      final nativeAvailable = await widget.nativeCalendar.supportsEditor();
      if (!mounted) return;
      final l10n = S.of(context);
      final provider = await showModalBottomSheet<_CalendarProvider>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(l10n.calendarProviderGoogle),
                  onTap: () => Navigator.pop(context, _CalendarProvider.google),
                ),
                if (nativeAvailable)
                  ListTile(
                    leading: Icon(
                      defaultTargetPlatform == TargetPlatform.iOS
                          ? Icons.apple
                          : Icons.calendar_month_outlined,
                    ),
                    title: Text(
                      defaultTargetPlatform == TargetPlatform.iOS
                          ? l10n.calendarProviderApple
                          : l10n.calendarProviderDevice,
                    ),
                    onTap: () =>
                        Navigator.pop(context, _CalendarProvider.native),
                  ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.calendarExportIcs),
                  onTap: () => Navigator.pop(context, _CalendarProvider.ics),
                ),
              ],
            ),
          ),
        ),
      );
      if (provider == null || !mounted) return;
      await _perform(provider);
    } finally {
      _choosing = false;
    }
  }

  Future<void> _perform(_CalendarProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final entry = EventCalendarEntry.fromEvent(widget.event);
      if (provider == _CalendarProvider.google) {
        final opened =
            await (widget.openGoogle?.call(entry.googleUri) ??
                launchUrl(
                  entry.googleUri,
                  mode: LaunchMode.externalApplication,
                ));
        if (!opened) throw StateError('Calendar could not be opened');
      } else if (provider == _CalendarProvider.native) {
        final result = await widget.nativeCalendar.openEditor(entry);
        if (result == NativeCalendarResult.unavailable) {
          throw StateError('Native calendar unavailable');
        }
        // A handoff is not evidence that the user saved the event.
        // Saved and cancelled also need no additional notification.
      } else {
        final box = context.findRenderObject()! as RenderBox;
        final origin = box.localToGlobal(Offset.zero) & box.size;
        await (widget.exportFile ?? exportCalendarFile)(
          entry.toIcs(),
          entry.fileName,
          origin,
        );
      }
    } catch (_) {
      if (!mounted) return;
      final l10n = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToAddToCalendar),
          action: SnackBarAction(
            label: provider != _CalendarProvider.ics
                ? l10n.calendarExportIcs
                : l10n.calendarRetry,
            onPressed: () => _perform(
              provider != _CalendarProvider.ics
                  ? _CalendarProvider.ics
                  : provider,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Semantics(
      label: l10n.addToCalendar,
      button: true,
      child: ListTile(
        leading: Icon(
          Icons.event_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(l10n.dateAndTime),
        subtitle: Text(widget.schedule),
        trailing: const Icon(Icons.open_in_new),
        onTap: _busy ? null : _pickCalendar,
      ),
    );
  }
}
