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
  });

  final SessionData session;
  final EventSelected onEventSelected;
  final ValueChanged<int>? onPendingInvitesChanged;

  @override
  State<EventsListPage> createState() => EventsListPageState();
}

class EventsListPageState extends State<EventsListPage> {
  final _api = EventsApi();
  final _invitationsApi = InvitationsApi();
  List<EventModel>? _events;
  Map<int, InvitationModel> _myInvitations = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = widget.session.token;
      final events = await _api.fetchEvents(token: token);
      List<InvitationModel> invitations = [];
      try {
        invitations = await _invitationsApi.fetchMyInvitations(token);
      } catch (_) {
        invitations = const [];
      }
      if (!mounted) return;
      setState(() {
        _events = events;
        _myInvitations = {
          for (final invitation in invitations) invitation.eventId: invitation
        };
        _notifyPendingInvites();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = S.of(context).unableToLoadFiestaaa;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _notifyPendingInvites() {
    if (widget.onPendingInvitesChanged == null) return;
    final pending =
        _myInvitations.values.where((inv) => inv.status == 'Waiting').length;
    widget.onPendingInvitesChanged!(pending);
  }

  @override
  void dispose() {
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
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: Colors.grey.shade500, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: Text(S.of(context).retry),
            ),
          ],
        ),
      );
    } else {
      final events = _events ?? [];
      if (events.isEmpty) {
        content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, color: Colors.grey.shade500, size: 40),
              const SizedBox(height: 12),
              Text(S.of(context).noFiestaaaYet),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh),
                label: Text(S.of(context).refresh),
              ),
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
        );
      }
    }

    return FiestaaaBackground(
      padding: const EdgeInsets.only(bottom: 16),
      child: SafeArea(child: content),
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
  });

  final List<EventModel> events;
  final EventSelected onEventSelected;
  final String sessionEmail;
  final Map<int, InvitationModel> invitations;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final pendingInvites =
        invitations.values.where((inv) => inv.status == 'Waiting').length;
    final sortedEvents = [...events]..sort((a, b) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      color: Colors.orange.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.mark_email_unread,
                            color: Colors.orange),
                        title: Text(
                          S.of(context).invitationsWaitingCount(pendingInvites),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: FiestaaaPalette.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                color: FiestaaaPalette.primary
                                    .withValues(alpha: 0.8)),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).yourFiestaaa,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: FiestaaaPalette.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onRefresh,
                        tooltip: S.of(context).refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = sortedEvents[index];
                      return _EventBubble(
                        event: event,
                        sessionEmail: sessionEmail,
                        invitation: invitations[event.id],
                        onTap: () {
                          onEventSelected(event);
                        },
                      );
                    },
                    childCount: sortedEvents.length,
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: FiestaaaPalette.cardGradient,
          borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: FiestaaaPalette.primary.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }

  _EventBadgeData? _badgeData(BuildContext context) {
    final isOwner =
        sessionEmail.toLowerCase() == event.ownerEmail.toLowerCase();
    if (isOwner) {
        return _EventBadgeData(
          label: S.of(context).organizer,
          color: FiestaaaPalette.primary,
          background: FiestaaaPalette.primary.withValues(alpha: 0.12),
          icon: Icons.emoji_events,
        );
    }

    if (invitation == null) {
      return null;
    }

    switch (invitation!.status) {
      case 'Accepted':
        return _EventBadgeData(
          label: S.of(context).participationConfirmed,
          color: Colors.green.shade800,
          background: Colors.green.shade100,
          icon: Icons.check_circle,
        );
      case 'Waiting':
        return _EventBadgeData(
          label: S.of(context).responseExpected,
          color: Colors.orange.shade800,
          background: Colors.orange.shade100,
          icon: Icons.hourglass_top,
        );
      case 'Declined':
        return _EventBadgeData(
          label: S.of(context).refused,
          color: Colors.grey.shade700,
          background: Colors.grey.shade200,
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
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

class _DecorativeWave extends StatelessWidget {
  const _DecorativeWave({
    required this.color,
    required this.size,
  });

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
