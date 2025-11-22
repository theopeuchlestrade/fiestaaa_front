import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';

typedef EventSelected = void Function(EventModel event);

class EventsListPage extends StatefulWidget {
  const EventsListPage({
    super.key,
    required this.onEventSelected,
    required this.session,
  });

  final SessionData session;
  final EventSelected onEventSelected;

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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les événements';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _api.dispose();
    _invitationsApi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final events = _events ?? [];
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aucun événement pour le moment.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _EventBubble(
            event: event,
            sessionEmail: widget.session.email,
            invitation: _myInvitations[event.id],
            onTap: () => widget.onEventSelected(event),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badge.background,
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
                              Text(
                                badge.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: badge.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 18, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${event.formattedDate} • ${event.formattedTime}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place,
                          size: 18, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(event.address)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _EventBadgeData? _badgeData(BuildContext context) {
    final isOwner =
        sessionEmail.toLowerCase() == event.ownerEmail.toLowerCase();
    if (isOwner) {
      return _EventBadgeData(
        label: 'Organisateur',
        color: Colors.deepOrange,
        background: Colors.deepOrange.withOpacity(0.12),
        icon: Icons.emoji_events,
      );
    }

    if (invitation == null) {
      return null;
    }

    switch (invitation!.status) {
      case 'Accepted':
        return _EventBadgeData(
          label: 'Participation confirmée',
          color: Colors.green.shade800,
          background: Colors.green.shade100,
          icon: Icons.check_circle,
        );
      case 'Waiting':
        return _EventBadgeData(
          label: 'Réponse attendue',
          color: Colors.orange.shade800,
          background: Colors.orange.shade100,
          icon: Icons.hourglass_top,
        );
      case 'Declined':
        return _EventBadgeData(
          label: 'Refusé',
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
