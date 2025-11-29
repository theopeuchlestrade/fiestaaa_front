import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_create_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_detail_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/events_list_page.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.initialShareToken,
    this.onShareTokenConsumed,
    this.onSessionUpdated,
  });

  final SessionData session;
  final VoidCallback onLogout;
  final String? initialShareToken;
  final VoidCallback? onShareTokenConsumed;
  final Future<void> Function(SessionData session)? onSessionUpdated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<EventsListPageState> _eventsKey = GlobalKey();
  final _shareApi = EventsApi();
  final _invitesApi = InvitationsApi();
  final _friendsApi = FriendsApi();
  int _selectedIndex = 0;
  bool _claimingShare = false;
  bool _shareHandled = false;
  late SessionData _session;
  int _pendingEventInvites = 0;
  int _pendingFriendRequests = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openEvent(EventModel event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          session: _session,
          onEventUpdated: () => _eventsKey.currentState?.reload(),
          onEventRemoved: _handleEventRemoved,
          onInvitationStatusChanged: _updateInvitationStatus,
        ),
      ),
    );
    if (!mounted) return;
    _eventsKey.currentState?.reload();
  }

  void _handleEventCreated() {
    setState(() {
      _selectedIndex = 0;
    });
    _eventsKey.currentState?.reload();
  }

  void _handleEventRemoved(int eventId) {
    if (_eventsKey.currentState != null) {
      _eventsKey.currentState!.removeEvent(eventId);
    }
  }

  void _updateInvitationStatus(int eventId, String status) {
    _eventsKey.currentState?.updateInvitationStatus(eventId, status);
  }

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadPendingBadges();
    if (widget.initialShareToken != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _claimShareIfNeeded());
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.token != oldWidget.session.token) {
      _session = widget.session;
      _loadPendingBadges();
    }
    if (widget.initialShareToken != oldWidget.initialShareToken &&
        widget.initialShareToken != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _claimShareIfNeeded());
    }
  }

  @override
  void dispose() {
    _shareApi.dispose();
    _invitesApi.dispose();
    _friendsApi.dispose();
    super.dispose();
  }

  Future<void> _loadPendingBadges() async {
    try {
      final invites = await _invitesApi.fetchMyInvitations(_session.token);
      if (!mounted) return;
      final waiting = invites.where((inv) => inv.status == 'Waiting').length;
      setState(() => _pendingEventInvites = waiting);
    } catch (_) {
      // ignore badge failures
    }

    try {
      final requests = await _friendsApi.fetchRequests(_session.token);
      if (!mounted) return;
      final pending = requests
          .where((r) => r.status == 'Pending' && r.isIncoming(_session.email))
          .length;
      setState(() => _pendingFriendRequests = pending);
    } catch (_) {
      // ignore badge failures
    }
  }

  Future<void> _claimShareIfNeeded() async {
    if (_shareHandled || widget.initialShareToken == null || _claimingShare) {
      return;
    }
    setState(() {
      _claimingShare = true;
    });
    try {
      final event = await _shareApi.claimShareToken(
        token: _session.token,
        shareToken: widget.initialShareToken!,
      );
      _shareHandled = true;
      widget.onShareTokenConsumed?.call();
      await _openEvent(event);
    } on ApiException catch (e) {
      _shareHandled = true;
      widget.onShareTokenConsumed?.call();
      _showSnack(e.message);
    } catch (_) {
      _shareHandled = true;
      widget.onShareTokenConsumed?.call();
      _showSnack('Lien de partage invalide ou expiré.');
    } finally {
      if (mounted) {
        setState(() {
          _claimingShare = false;
        });
      }
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EventsListPage(
        key: _eventsKey,
        session: _session,
        onEventSelected: _openEvent,
        onPendingInvitesChanged: (count) =>
            setState(() => _pendingEventInvites = count),
      ),
      EventCreatePage(
        session: _session,
        onEventCreated: _handleEventCreated,
      ),
      FriendsPage(
        session: _session,
        onPendingRequestsChanged: (count) =>
            setState(() => _pendingFriendRequests = count),
      ),
      ProfilePage(
        session: _session,
        onLogout: widget.onLogout,
        onSessionUpdated: (session) async {
          setState(() {
            _session = session;
          });
          if (widget.onSessionUpdated != null) {
            await widget.onSessionUpdated!(session);
          }
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: _iconWithBadge(Icons.event_note, _pendingEventInvites),
            label: 'Événements',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Créer',
          ),
          BottomNavigationBarItem(
            icon: _iconWithBadge(Icons.group, _pendingFriendRequests),
            label: 'Amis',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _iconWithBadge(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
