import 'dart:async';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/async_content.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef EventSelected = Future<void> Function(EventModel event);

class EventsListPage extends StatefulWidget {
  const EventsListPage({
    super.key,
    required this.onEventSelected,
    required this.session,
    this.onPendingInvitesChanged,
    this.onOpenTrash,
    this.eventsApi,
    this.invitationsApi,
    this.query = '',
    this.view = 'upcoming',
    this.onCriteriaChanged,
    this.onCreate,
  });
  final SessionData session;
  final EventSelected onEventSelected;
  final ValueChanged<int>? onPendingInvitesChanged;
  final VoidCallback? onOpenTrash;
  final EventsApi? eventsApi;
  final InvitationsApi? invitationsApi;
  final String query;
  final String view;
  final void Function(String query, String view)? onCriteriaChanged;
  final VoidCallback? onCreate;
  @override
  State<EventsListPage> createState() => EventsListPageState();
}

class EventsListPageState extends State<EventsListPage> {
  final _refreshQueue = RefreshQueue();
  final _scroll = ScrollController();
  late final _search = TextEditingController(text: widget.query);
  late String _query = widget.query;
  late String _view = widget.view;
  Timer? _debounce;
  int _scopeGeneration = 0;
  int _paginationGeneration = 0;
  late final EventsApi _api = widget.eventsApi ?? EventsApi();
  late final InvitationsApi _invitationsApi =
      widget.invitationsApi ?? InvitationsApi();
  List<EventModel>? _events;
  Map<int, InvitationModel> _myInvitations = {};
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _invitationsFailed = false;
  bool _hasAnyEvents = true;
  String? _nextCursor;
  String? _error;
  bool _moreFailed = false;
  String get _sort => _view == 'past' ? 'start_desc' : 'start_asc';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didUpdateWidget(covariant EventsListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.token != widget.session.token) {
      _scopeGeneration++;
      _events = null;
      _myInvitations = {};
      _loadEvents();
    }
    if (widget.query != oldWidget.query || widget.view != oldWidget.view) {
      _setCriteria(widget.query, widget.view, notify: false);
    }
  }

  void _setCriteria(String query, String view, {bool notify = true}) {
    _debounce?.cancel();
    query = query.trim();
    if (_search.text != query) {
      _search.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    if (query == _query && view == _view) return;
    setState(() {
      _query = query;
      _view = view;
      _scopeGeneration++;
      _events = null;
      _nextCursor = null;
      _loading = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (notify) widget.onCriteriaChanged?.call(query, view);
    _loadEvents();
  }

  Future<void> reload() => _loadEvents();
  void removeEvent(int eventId) {
    setState(() {
      _events = _events?.where((e) => e.id != eventId).toList();
      _myInvitations.remove(eventId);
    });
  }

  void updateInvitationStatus(int eventId, String status) {
    final current = _myInvitations[eventId];
    if (current == null) return;
    setState(() {
      _myInvitations[eventId] = InvitationModel(
        eventId: current.eventId,
        email: current.email,
        status: status,
        dateInvi: current.dateInvi,
        eventName: current.eventName,
      );
      _notifyPendingInvites();
    });
  }

  Future<void> _loadEvents() => _refreshQueue.run('events', _loadEventsOnce);
  Future<void> _loadEventsOnce() async {
    if (!mounted) return;
    final scope = (_scopeGeneration, widget.session.token);
    final query = _query, view = _view, sort = _sort;
    bool current() =>
        mounted && scope == (_scopeGeneration, widget.session.token);
    final target = _events?.length ?? 0;
    _paginationGeneration++;
    setState(() {
      _loading = _events == null;
      _refreshing = true;
      _loadingMore = false;
      _error = null;
      _moreFailed = false;
    });
    try {
      final rebuilt = <int, EventModel>{};
      final seenCursors = <String>{};
      String? cursor;
      do {
        final page = await _api.fetchEventsPage(
          token: widget.session.token,
          query: query,
          view: view,
          sort: sort,
          cursor: cursor,
        );
        if (!current()) return;
        for (final event in page.items) {
          rebuilt[event.id] = event;
        }
        cursor = page.nextCursor;
        if (cursor != null && !seenCursors.add(cursor)) {
          throw StateError('Repeated cursor');
        }
      } while (cursor != null && rebuilt.length < target);
      var hasAny = true;
      if (rebuilt.isEmpty && query.isEmpty) {
        final any = await _api.fetchEventsPage(
          token: widget.session.token,
          view: 'all',
          sort: 'start_asc',
          limit: 1,
        );
        if (!current()) return;
        hasAny = any.items.isNotEmpty;
      }
      setState(() {
        _events = rebuilt.values.toList();
        _nextCursor = cursor;
        _hasAnyEvents = hasAny;
        _loading = false;
      });
      try {
        final invitations = await _invitationsApi.fetchMyInvitations(
          widget.session.token,
        );
        if (!current()) return;
        setState(() {
          _myInvitations = {for (final i in invitations) i.eventId: i};
          _invitationsFailed = false;
          _notifyPendingInvites();
        });
      } catch (_) {
        if (current()) setState(() => _invitationsFailed = true);
      }
    } catch (_) {
      if (current()) setState(() => _error = S.of(context).eventsRefreshFailed);
    } finally {
      if (current()) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final scope = (_scopeGeneration, _paginationGeneration);
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _refreshing) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await _api.fetchEventsPage(
        token: widget.session.token,
        cursor: cursor,
        query: _query,
        view: _view,
        sort: _sort,
      );
      if (!mounted || scope != (_scopeGeneration, _paginationGeneration)) {
        return;
      }
      final known = _events?.map((e) => e.id).toSet() ?? <int>{};
      setState(() {
        _events = [...?_events, ...page.items.where((e) => known.add(e.id))];
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && scope == (_scopeGeneration, _paginationGeneration)) {
        setState(() => _moreFailed = true);
      }
    } finally {
      if (mounted && scope == (_scopeGeneration, _paginationGeneration)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _notifyPendingInvites() => widget.onPendingInvitesChanged?.call(
    _myInvitations.values.where((i) => i.status == 'Waiting').length,
  );
  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    _refreshQueue.dispose();
    if (widget.eventsApi == null) _api.dispose();
    if (widget.invitationsApi == null) _invitationsApi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final pending = _myInvitations.values
        .where((i) => i.status == 'Waiting')
        .length;
    final filters = {
      'upcoming': l.eventsUpcoming,
      'invitations': l.eventsInvitations,
      'owned': l.eventsOwned,
      'past': l.eventsPast,
    };
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_events == null && _error != null) {
      content = AsyncNotice(
        message: l.unableToLoadFiestaaa,
        actionLabel: l.retry,
        onAction: reload,
      );
    } else if (_events?.isEmpty ?? true) {
      final searching = _query.isNotEmpty;
      content = AsyncNotice(
        icon: Icons.celebration_outlined,
        message: searching
            ? l.eventsEmptySearch
            : !_hasAnyEvents
            ? '${l.noFiestaaaYet}\n${l.eventsEmptyHelp}'
            : l.eventsEmptyFilter,
        actionLabel: searching
            ? l.eventsClearSearch
            : !_hasAnyEvents
            ? l.eventsFirstCreate
            : l.eventsChangeFilter,
        onAction: searching
            ? () => _setCriteria('', _view)
            : !_hasAnyEvents
            ? () => widget.onCreate?.call()
            : () => _setCriteria('', 'upcoming'),
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
          final columns = largeText
              ? 1
              : constraints.maxWidth > 1080
              ? 3
              : constraints.maxWidth >= 720
              ? 2
              : 1;
          final events = _events!;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount:
                  (events.length / columns).ceil() +
                  (_nextCursor == null ? 0 : 1),
              itemBuilder: (context, row) {
                final start = row * columns;
                if (start >= events.length) {
                  return Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : TextButton.icon(
                            onPressed: _refreshing ? null : _loadMore,
                            icon: Icon(
                              _moreFailed ? Icons.refresh : Icons.expand_more,
                            ),
                            label: Text(
                              _moreFailed ? l.retry : l.eventsLoadMore,
                            ),
                          ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col > 0) const SizedBox(width: 16),
                        Expanded(
                          child: start + col < events.length
                              ? _EventCard(
                                  event: events[start + col],
                                  invitation:
                                      _myInvitations[events[start + col].id],
                                  email: widget.session.email,
                                  onTap: () => widget.onEventSelected(
                                    events[start + col],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    }
    return FiestaaaPageLayout(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    maxLength: 200,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: l.eventsSearch,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: l.eventsClearSearch,
                        onPressed: () => _setCriteria('', _view),
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () => _setCriteria(value, _view),
                      );
                    },
                  ),
                ),
                if (widget.onOpenTrash != null)
                  IconButton(
                    tooltip: l.eventsTrash,
                    onPressed: widget.onOpenTrash,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in filters.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _view == entry.key,
                    onSelected: (_) => _setCriteria(_search.text, entry.key),
                  ),
              ],
            ),
          ),
          if (pending > 0)
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(l.invitationsWaitingCount(pending)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _setCriteria('', 'invitations'),
            ),
          if (_refreshing && !_loading) const LinearProgressIndicator(),
          if (_events != null && _error != null)
            AsyncNotice(
              compact: true,
              message: _error!,
              actionLabel: l.retry,
              onAction: reload,
            ),
          if (_invitationsFailed)
            AsyncNotice(
              compact: true,
              message: l.eventsInvitationsFailed,
              actionLabel: l.retry,
              onAction: reload,
            ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.invitation,
    required this.email,
    required this.onTap,
  });
  final EventModel event;
  final InvitationModel? invitation;
  final String email;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = S.of(context), theme = Theme.of(context);
    final owner = email.toLowerCase() == event.ownerEmail.toLowerCase();
    final label = event.isFinished
        ? l.finishedEvent
        : owner
        ? l.organizer
        : invitation?.status == 'Waiting'
        ? l.responseExpected
        : invitation?.status == 'Accepted'
        ? l.participationConfirmed
        : null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.primary, width: 3),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat.yMMMd(locale).format(event.date)} · ${event.formattedTime}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(event.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                event.shortAddressSummary.primary,
                style: theme.textTheme.bodyMedium,
              ),
              if (label != null) ...[
                const SizedBox(height: 12),
                Chip(label: Text(label)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
