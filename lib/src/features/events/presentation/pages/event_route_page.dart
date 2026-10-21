import 'package:fiestaaa_front/src/core/realtime_client.dart';

import 'dart:async';

import 'package:fiestaaa_front/src/core/event_data_store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/async_content.dart';

import 'event_detail_page.dart';
export 'event_detail_page.dart' show EventModule;

class EventRoutePage extends StatefulWidget {
  const EventRoutePage({
    super.key,
    required this.session,
    required this.eventId,
    this.api,
    this.module,
    this.realtimeClientFactory,
  });

  final SessionData session;
  final int eventId;
  final EventsApi? api;
  final EventModule? module;
  final RealtimeClient Function(String token, int eventId)?
  realtimeClientFactory;

  @override
  State<EventRoutePage> createState() => _EventRoutePageState();
}

class _EventRoutePageState extends State<EventRoutePage> {
  late final EventsApi _api;
  EventModel? _event;
  bool _failed = false;
  int _loadGeneration = 0;
  StreamSubscription<EventAccessChange>? _accessSub;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? EventsApi();
    _event = EventDataStore.instance.peek<EventModel>(
      widget.session.token,
      widget.eventId,
      'context',
      fresh: widget.module != null,
    );
    _accessSub = EventDataStore.instance.accessChanges.listen((change) {
      if (!mounted ||
          change.generation != EventDataStore.instance.generation ||
          change.eventId != widget.eventId ||
          !change.denied) {
        return;
      }
      _loadGeneration++;
      setState(() {
        _event = null;
        _failed = true;
      });
    });
    _load(initial: true);
  }

  @override
  void didUpdateWidget(covariant EventRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.session.token != widget.session.token ||
        oldWidget.session.email != widget.session.email ||
        oldWidget.session.publicId != widget.session.publicId) {
      _event = EventDataStore.instance.peek<EventModel>(
        widget.session.token,
        widget.eventId,
        'context',
        fresh: widget.module != null,
      );
      _load(initial: true);
    }
  }

  Future<void> _load({bool initial = false}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _failed = false;
      if (!initial) {
        EventDataStore.instance.invalidateEvent(widget.eventId);
        _event = null;
      }
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
    _accessSub?.cancel();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(
        widget.module == null ? '/events' : '/events/${widget.eventId}',
      );
    }
  }

  String? _moduleTitle(BuildContext context) {
    final l = S.of(context);
    return switch (widget.module) {
      EventModule.items => l.itemsModule,
      EventModule.polls => l.pollsModule,
      EventModule.expenses => l.expensesModule,
      EventModule.carpools => l.carpools,
      EventModule.participants => l.participants,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_event == null) {
      final l = S.of(context);
      final title = _moduleTitle(context);
      return Scaffold(
        body: FiestaaaPageLayout(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BackButton(onPressed: _back),
                    const SizedBox(width: 8),
                    Expanded(
                      child: title != null
                          ? Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: _LoadingBlock(height: 28, width: 220),
                            ),
                    ),
                  ],
                ),
              ),
              if (_failed)
                AsyncNotice(
                  message: l.unableToLoadFiestaaa,
                  actionLabel: l.retry,
                  onAction: _load,
                  compact: true,
                )
              else
                Semantics(
                  key: const ValueKey('event-route-loading'),
                  label: l.loading,
                  liveRegion: true,
                  child: const ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(minHeight: 2),
                        SizedBox(height: 20),
                        _LoadingBlock(height: 132),
                        SizedBox(height: 16),
                        _LoadingBlock(height: 84),
                        SizedBox(height: 16),
                        _LoadingBlock(height: 84),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return EventDetailPage(
      eventsApi: _api,
      contextRefreshFailed: _failed,
      onContextRetry: () => _load(initial: true),
      realtimeClientFactory: widget.realtimeClientFactory,
      event: _event!,
      module: widget.module,
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

/// Neutral placeholders only: no event information or restricted controls.
class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
