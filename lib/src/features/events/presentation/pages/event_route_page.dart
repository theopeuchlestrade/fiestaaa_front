import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'event_detail_page.dart';

class EventRoutePage extends StatefulWidget {
  const EventRoutePage({
    super.key,
    required this.session,
    required this.eventId,
    this.api,
  });

  final SessionData session;
  final int eventId;
  final EventsApi? api;

  @override
  State<EventRoutePage> createState() => _EventRoutePageState();
}

class _EventRoutePageState extends State<EventRoutePage> {
  late final EventsApi _api;
  EventModel? _event;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? EventsApi();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _failed = false;
      _event = null;
    });
    try {
      final event = await _api.fetchEventById(
        token: widget.session.token,
        eventId: widget.eventId,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _event = event);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  AppBar _appBar(BuildContext context) => AppBar(
    title: const Text('Fiestaaa'),
    leading: BackButton(
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/events');
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        appBar: _appBar(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.of(context).unableToLoadFiestaaa),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: Text(S.of(context).retry)),
            ],
          ),
        ),
      );
    }
    if (_event == null) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return EventDetailPage(
      event: _event!,
      session: widget.session,
      onEventRemoved: (_) => context.go('/events'),
      onInvitationStatusChanged: (_, status) {
        if (status == 'Declined' || status == 'Expired') {
          context.go('/events');
        }
      },
    );
  }
}
