import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';

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
  });

  final SessionData session;
  final EventSelected onEventSelected;
  final ValueChanged<int>? onPendingInvitesChanged;
  final VoidCallback? onOpenTrash;
  final EventsApi? eventsApi;
  final InvitationsApi? invitationsApi;

  @override
  State<EventsListPage> createState() => EventsListPageState();
}

class EventsListPageState extends State<EventsListPage> {
  final _refreshQueue = RefreshQueue();
  int _scopeGeneration = 0;
  int _paginationGeneration = 0;

  late final EventsApi _api = widget.eventsApi ?? EventsApi();
  late final InvitationsApi _invitationsApi =
      widget.invitationsApi ?? InvitationsApi();
  List<EventModel>? _events;
  Map<int, InvitationModel> _myInvitations = {};
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  String? _error;

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
  }

  Future<void> reload() => _loadEvents();

  void removeEvent(int eventId) {
    final events = _events;
    if (events == null) return;
    setState(() {
      _events = events.where((event) => event.id != eventId).toList();
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

  Future<void> _loadEvents() =>
      _refreshQueue.run('_loadEvents', () => _loadEventsOnce());

  Future<void> _loadEventsOnce() async {
    if (!mounted) return;
    final requestScope = (_scopeGeneration, widget.session.token);
    _paginationGeneration++;
    _loadingMore = false;
    setState(() {
      _loading = _events == null;
      _error = null;
    });
    try {
      final token = widget.session.token;
      final page = await _api.fetchEventsPage(token: token);
      List<InvitationModel> invitations = [];
      try {
        invitations = await _invitationsApi.fetchMyInvitations(token);
      } catch (_) {
        if (!mounted ||
            requestScope != (_scopeGeneration, widget.session.token)) {
          return;
        }
        invitations = const [];
      }
      if (!mounted ||
          requestScope != (_scopeGeneration, widget.session.token)) {
        return;
      }
      setState(() {
        _events = page.items;
        _nextCursor = page.nextCursor;
        _myInvitations = {
          for (final invitation in invitations) invitation.eventId: invitation,
        };
        _notifyPendingInvites();
      });
    } catch (e) {
      if (!mounted ||
          requestScope != (_scopeGeneration, widget.session.token)) {
        return;
      }
      setState(() {
        _error = S.of(context).unableToLoadFiestaaa;
      });
    } finally {
      if (mounted && requestScope == (_scopeGeneration, widget.session.token)) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final requestScope = (_scopeGeneration, _paginationGeneration);
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.fetchEventsPage(
        token: widget.session.token,
        cursor: cursor,
      );
      if (!mounted ||
          requestScope != (_scopeGeneration, _paginationGeneration)) {
        return;
      }
      final known = _events?.map((event) => event.id).toSet() ?? <int>{};
      setState(() {
        _events = [
          ...?_events,
          ...page.items.where((event) => known.add(event.id)),
        ];
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (!mounted ||
          requestScope != (_scopeGeneration, _paginationGeneration)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).unableToLoadFiestaaa)),
      );
    } finally {
      if (mounted &&
          requestScope == (_scopeGeneration, _paginationGeneration)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _notifyPendingInvites() {
    if (widget.onPendingInvitesChanged == null) return;
    final pending = _myInvitations.values
        .where((inv) => inv.status == 'Waiting')
        .length;
    widget.onPendingInvitesChanged!(pending);
  }

  @override
  void dispose() {
    _refreshQueue.dispose();
    _api.dispose();
    _invitationsApi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      final theme = Theme.of(context);
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: theme.fiestaaaMutedText, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: reload, child: Text(S.of(context).retry)),
          ],
        ),
      );
    } else {
      final events = _events ?? [];
      if (events.isEmpty) {
        final theme = Theme.of(context);
        content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, color: theme.fiestaaaMutedText, size: 40),
              const SizedBox(height: 12),
              Text(S.of(context).noFiestaaaYet),
            ],
          ),
        );
      } else {
        content = _EventsGrid(
          events: events,
          onEventSelected: widget.onEventSelected,
          sessionEmail: widget.session.email,
          invitations: _myInvitations,
          onRefresh: _loadEvents,
          onLoadMore: _nextCursor == null ? null : _loadMore,
          loadingMore: _loadingMore,
        );
      }
    }

    return FiestaaaBackground(
      padding: const EdgeInsets.only(bottom: 16),
      child: SafeArea(
        child: Column(
          children: [
            if (widget.onOpenTrash != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'fr'
                      ? 'Corbeille'
                      : 'Trash',
                  onPressed: widget.onOpenTrash,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _EventsGrid extends StatelessWidget {
  const _EventsGrid({
    required this.events,
    required this.onEventSelected,
    required this.sessionEmail,
    required this.invitations,
    required this.onRefresh,
    required this.onLoadMore,
    required this.loadingMore,
  });

  final List<EventModel> events;
  final EventSelected onEventSelected;
  final String sessionEmail;
  final Map<int, InvitationModel> invitations;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    final pendingInvites = invitations.values
        .where((inv) => inv.status == 'Waiting')
        .length;
    final sortedEvents = [...events]
      ..sort((a, b) {
        final waitingA = invitations[a.id]?.status == 'Waiting';
        final waitingB = invitations[b.id]?.status == 'Waiting';
        if (waitingA == waitingB) return 0;
        return waitingA ? -1 : 1; // waiting first
      });

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 32,
      edgeOffset: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 720;
          final crossAxisCount = constraints.maxWidth > 1080
              ? 3
              : constraints.maxWidth > 720
              ? 2
              : 1;
          final childAspectRatio = isTablet ? 1.9 : 1.3;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              if (pendingInvites > 0)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      color: Theme.of(context).colorScheme
                          .fiestaaaStatus(FiestaaaStatusTone.warning)
                          .background,
                      child: ListTile(
                        leading: Icon(
                          Icons.mark_email_unread,
                          color: Theme.of(context).colorScheme
                              .fiestaaaStatus(FiestaaaStatusTone.warning)
                              .foreground,
                        ),
                        title: Text(
                          S.of(context).invitationsWaitingCount(pendingInvites),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme
                                    .fiestaaaStatus(FiestaaaStatusTone.warning)
                                    .foreground,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FiestaaaPalette.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: FiestaaaPalette.primary.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).yourFiestaaa,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = sortedEvents[index];
                    return _EventBubble(
                      event: event,
                      sessionEmail: sessionEmail,
                      invitation: invitations[event.id],
                      onTap: () {
                        onEventSelected(event);
                      },
                    );
                  }, childCount: sortedEvents.length),
                ),
              ),
              if (onLoadMore != null)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: loadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              onPressed: onLoadMore,
                              icon: const Icon(Icons.expand_more),
                              label: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'fr'
                                    ? 'Charger plus'
                                    : 'Load more',
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventBubble extends StatelessWidget {
  const _EventBubble({
    required this.event,
    required this.sessionEmail,
    required this.onTap,
    this.invitation,
  });

  final EventModel event;
  final InvitationModel? invitation;
  final String sessionEmail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = _badgeData(context);
    final borderRadius = BorderRadius.circular(28);

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          gradient: FiestaaaPalette.cardGradientFor(
            Theme.of(context).brightness,
          ),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: FiestaaaPalette.primary.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -18,
                child: _DecorativeWave(
                  color: Colors.white.withValues(alpha: 0.18),
                  size: 120,
                ),
              ),
              Positioned(
                bottom: -22,
                left: -10,
                child: _DecorativeWave(
                  color: Colors.white.withValues(alpha: 0.12),
                  size: 140,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badge.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: badge.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    badge.icon,
                                    size: 16,
                                    color: badge.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      badge.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: badge.color,
                                            fontWeight: FontWeight.w700,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${event.formattedDate} • ${event.formattedTime}',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.address,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _EventBadgeData? _badgeData(BuildContext context) {
    if (event.isFinished) {
      final finished = Theme.of(
        context,
      ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.warning);
      return _EventBadgeData(
        label: S.of(context).finishedEvent,
        color: finished.foreground,
        background: finished.background,
        border: finished.border,
        icon: Icons.lock_clock_outlined,
      );
    }

    final isOwner =
        sessionEmail.toLowerCase() == event.ownerEmail.toLowerCase();
    if (isOwner) {
      return _EventBadgeData(
        label: S.of(context).organizer,
        color: FiestaaaPalette.primary,
        background: FiestaaaPalette.primary.withValues(alpha: 0.16),
        border: FiestaaaPalette.primary.withValues(alpha: 0.32),
        icon: Icons.emoji_events,
      );
    }

    if (invitation == null) {
      return null;
    }

    switch (invitation!.status) {
      case 'Accepted':
        final accepted = Theme.of(
          context,
        ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.success);
        return _EventBadgeData(
          label: S.of(context).participationConfirmed,
          color: accepted.foreground,
          background: accepted.background,
          border: accepted.border,
          icon: Icons.check_circle,
        );
      case 'Waiting':
        final waiting = Theme.of(
          context,
        ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.warning);
        return _EventBadgeData(
          label: S.of(context).responseExpected,
          color: waiting.foreground,
          background: waiting.background,
          border: waiting.border,
          icon: Icons.hourglass_top,
        );
      case 'Declined':
        final declined = Theme.of(
          context,
        ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.neutral);
        return _EventBadgeData(
          label: S.of(context).refused,
          color: declined.foreground,
          background: declined.background,
          border: declined.border,
          icon: Icons.remove_circle_outline,
        );
      default:
        return null;
    }
  }
}

class _EventBadgeData {
  const _EventBadgeData({
    required this.label,
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;
}

class _DecorativeWave extends StatelessWidget {
  const _DecorativeWave({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.6,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      ),
    );
  }
}
