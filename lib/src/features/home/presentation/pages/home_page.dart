import 'package:fiestaaa_front/src/core/api_error_localizer.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/async_content.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/realtime_status_banner.dart';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_create_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/events_list_page.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.initialShareToken,
    this.notificationIntent,
    this.notificationIntentSerial = 0,
    this.onShareTokenConsumed,
    this.onSessionUpdated,
    this.localeService,
    this.themeService,
    this.initialIndex = 0,
    this.eventsQuery = '',
    this.eventsView = 'upcoming',
  });

  final SessionData session;
  final VoidCallback onLogout;
  final String? initialShareToken;
  final PushNotificationIntent? notificationIntent;
  final int notificationIntentSerial;
  final VoidCallback? onShareTokenConsumed;
  final Future<void> Function(SessionData session)? onSessionUpdated;
  final LocaleService? localeService;
  final ThemeService? themeService;
  final int initialIndex;
  final String eventsQuery;
  final String eventsView;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _refreshQueue = RefreshQueue();
  int _scopeGeneration = 0;

  final GlobalKey<EventsListPageState> _eventsKey = GlobalKey();
  final _shareApi = EventsApi();
  final _invitesApi = InvitationsApi();
  final _friendsApi = FriendsApi();
  RealtimeClient? _realtime;
  late int _selectedIndex;
  bool _claimingShare = false;
  bool _shareHandled = false;
  late SessionData _session;
  int _pendingEventInvites = 0;
  int _pendingFriendRequests = 0;
  int _friendsRequestsOpenSerial = 0;
  int _lastHandledNotificationIntentSerial = 0;
  int _badgesGeneration = 0;
  late List<Widget?> _pages;
  late String _eventsQuery = widget.eventsQuery;
  late String _eventsView = widget.eventsView;

  void _onItemTapped(int index) {
    const locations = ['/events', '/events/new', '/friends', '/profile'];
    context.go(
      index == 0
          ? Uri(
              path: '/events',
              queryParameters: {
                'view': _eventsView,
                if (_eventsQuery.isNotEmpty) 'q': _eventsQuery,
              },
            ).toString()
          : locations[index],
    );
  }

  Future<void> _openEvent(EventModel event) async {
    await context.push('/events/${event.id}');
    if (!mounted) return;
    _eventsKey.currentState?.reload();
  }

  Future<void> _openTrash() async {
    await context.push('/trash');
    _eventsKey.currentState?.reload();
  }

  void _handleEventCreated() {
    context.go('/events');
  }

  void _startRealtime() {
    _realtime?.dispose();
    _realtime = RealtimeClient(token: _session.token)..connect();
    _realtime?.stream.listen(_handleRealtimeMessage);
  }

  void _handleRealtimeMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'realtime.ready':
        _eventsKey.currentState?.reload();
        _loadPendingBadges();
        break;
      case 'events.changed':
        _eventsKey.currentState?.reload();
        break;
      case 'invitations.changed':
        _eventsKey.currentState?.reload();
        _loadPendingBadges();
        break;
      case 'friend_requests.changed':
        _loadPendingBadges();
        break;
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _selectedIndex = widget.initialIndex.clamp(0, 3).toInt();
    _pages = List<Widget?>.filled(4, null);
    _loadPendingBadges();
    _startRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationIntentIfNeeded();
    });
    if (widget.initialShareToken != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _claimShareIfNeeded(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedIndex = widget.initialIndex.clamp(0, 3);
    if (widget.initialIndex == 0 &&
        (widget.eventsQuery != _eventsQuery ||
            widget.eventsView != _eventsView)) {
      _eventsQuery = widget.eventsQuery;
      _eventsView = widget.eventsView;
      _pages[0] = _buildPage(0);
    }
    if (widget.session.token != oldWidget.session.token) {
      _scopeGeneration++;
      _session = widget.session;
      _pages = List<Widget?>.filled(4, null);
      _loadPendingBadges();
      _startRealtime();
    }
    if (widget.initialShareToken != oldWidget.initialShareToken &&
        widget.initialShareToken != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _claimShareIfNeeded(),
      );
    }
    if (widget.notificationIntentSerial != oldWidget.notificationIntentSerial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationIntentIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _refreshQueue.dispose();
    _badgesGeneration++;
    _shareApi.dispose();
    _invitesApi.dispose();
    _friendsApi.dispose();
    _realtime?.dispose();
    super.dispose();
  }

  Future<void> _loadPendingBadges() =>
      _refreshQueue.run('_loadPendingBadges', () => _loadPendingBadgesOnce());

  Future<void> _loadPendingBadgesOnce() async {
    if (!mounted) return;
    final requestScope = (_scopeGeneration, _session.token);
    final generation = ++_badgesGeneration;
    try {
      final invites = await _invitesApi.fetchMyInvitations(_session.token);
      if (!mounted || generation != _badgesGeneration) return;
      final waiting = invites.where((inv) => inv.status == 'Waiting').length;
      setState(() => _pendingEventInvites = waiting);
    } catch (_) {
      if (!mounted || requestScope != (_scopeGeneration, _session.token)) {
        return;
      }
      // ignore badge failures
    }

    try {
      final requests = await _friendsApi.fetchRequests(_session.token);
      if (!mounted || generation != _badgesGeneration) return;
      final pending = requests
          .where((r) => r.status == 'Pending' && r.isIncoming(_session.email))
          .length;
      setState(() => _pendingFriendRequests = pending);
    } catch (_) {
      if (!mounted || requestScope != (_scopeGeneration, _session.token)) {
        return;
      }
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
      if (!mounted) return;
      _showSnack(
        localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).shareLinkInvalid,
        ),
      );
    } on ApiTransportException {
      if (!mounted) return;
      _shareHandled = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).eventNetworkUnavailable),
          action: SnackBarAction(
            label: S.of(context).retry,
            onPressed: _claimShareIfNeeded,
          ),
        ),
      );
    } catch (_) {
      _shareHandled = true;
      widget.onShareTokenConsumed?.call();
      if (!mounted) return;
      _showSnack(S.of(context).shareLinkInvalid);
    } finally {
      if (mounted) {
        setState(() {
          _claimingShare = false;
        });
      }
    }
  }

  void _handleNotificationIntentIfNeeded() {
    if (!mounted ||
        widget.notificationIntentSerial == 0 ||
        widget.notificationIntentSerial ==
            _lastHandledNotificationIntentSerial) {
      return;
    }

    _lastHandledNotificationIntentSerial = widget.notificationIntentSerial;
    final intent = widget.notificationIntent;
    if (intent == null || !intent.opensFriendRequests) return;

    setState(() {
      _selectedIndex = 2;
      _friendsRequestsOpenSerial++;
    });
    _loadPendingBadges();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    _pages[_selectedIndex] ??= _buildPage(_selectedIndex);

    final body = RealtimeStatusBanner(
      stream: _realtime?.stream,
      child: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          _pages.length,
          (index) => _pages[index] ?? const SizedBox.shrink(),
        ),
      ),
    );
    final labels = [l10n.fiestaaa, l10n.create, l10n.friends, l10n.profile];
    final icons = [
      Icons.event_note,
      Icons.add_circle_outline,
      Icons.group,
      Icons.person,
    ];
    final counts = [_pendingEventInvites, 0, _pendingFriendRequests, 0];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: _onItemTapped,
                      destinations: List.generate(
                        4,
                        (i) => NavigationRailDestination(
                          icon: CountedIcon(
                            icon: icons[i],
                            count: counts[i],
                            label: labels[i],
                          ),
                          label: Text(labels[i]),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  items: List.generate(
                    4,
                    (i) => BottomNavigationBarItem(
                      icon: CountedIcon(
                        icon: icons[i],
                        count: counts[i],
                        label: labels[i],
                      ),
                      label: labels[i],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => EventsListPage(
        key: _eventsKey,
        session: _session,
        onEventSelected: _openEvent,
        onPendingInvitesChanged: (count) =>
            setState(() => _pendingEventInvites = count),
        onOpenTrash: _openTrash,
        query: _eventsQuery,
        view: _eventsView,
        onCreate: () => context.go('/events/new'),
        onCriteriaChanged: (query, view) => context.go(
          Uri(
            path: '/events',
            queryParameters: {'view': view, if (query.isNotEmpty) 'q': query},
          ).toString(),
        ),
      ),
      1 => EventCreatePage(
        session: _session,
        onEventCreated: _handleEventCreated,
      ),
      2 => FriendsPage(
        session: _session,
        onPendingRequestsChanged: (count) =>
            setState(() => _pendingFriendRequests = count),
        realtimeStream: _realtime?.stream,
        requestsOpenSerial: _friendsRequestsOpenSerial,
      ),
      _ => ProfilePage(
        session: _session,
        onLogout: widget.onLogout,
        onSessionUpdated: (session) async {
          setState(() {
            _session = session;
            _pages = List<Widget?>.filled(4, null);
          });
          if (widget.onSessionUpdated != null) {
            await widget.onSessionUpdated!(session);
          }
        },
        localeService: widget.localeService,
        themeService: widget.themeService,
      ),
    };
  }
}
