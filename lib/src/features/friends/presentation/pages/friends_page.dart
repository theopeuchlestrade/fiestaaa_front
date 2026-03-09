import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _FriendsTab { friends, requests, add }

enum _FriendMenuAction { remove }

class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    required this.session,
    this.onPendingRequestsChanged,
    this.realtimeStream,
  });

  final SessionData session;
  final ValueChanged<int>? onPendingRequestsChanged;
  final Stream<Map<String, dynamic>>? realtimeStream;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  final _api = FriendsApi();
  final _inviteController = TextEditingController();
  final _friendsFilterController = TextEditingController();
  late final TabController _tabController;
  Timer? _debounce;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _requests = [];
  List<FriendSearchResult> _suggestions = [];
  bool _loading = true;
  bool _loadingRequests = true;
  bool _searching = false;
  bool _sending = false;
  String? _error;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _FriendsTab.values.length,
      vsync: this,
    );
    _inviteController.addListener(_onInviteQueryChanged);
    _friendsFilterController.addListener(_onFriendFilterChanged);
    _refreshAll();
    _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeSub?.cancel();
    _inviteController.dispose();
    _friendsFilterController.dispose();
    _tabController.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FriendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.realtimeStream != widget.realtimeStream) {
      _realtimeSub?.cancel();
      _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchFriends(), _fetchRequests()]);
  }

  void _handleRealtime(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    if (type == 'friend_requests.changed' || type == 'friendships.changed') {
      _refreshAll();
    }
  }

  Future<void> _fetchFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchFriends(widget.session.token);
      if (!mounted) return;
      setState(() => _friends = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = S.of(context).unableToLoadFriends);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loadingRequests = true;
      _requestError = null;
    });
    try {
      final data = await _api.fetchRequests(widget.session.token);
      if (!mounted) return;
      final pending = data.where((r) => r.status == 'Pending').toList();
      setState(() => _requests = pending);
      _notifyPendingRequests(pending);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _requestError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _requestError = S.of(context).unableToLoadRequests);
    } finally {
      if (mounted) {
        setState(() => _loadingRequests = false);
      }
    }
  }

  void _notifyPendingRequests(List<FriendRequestModel> list) {
    if (widget.onPendingRequestsChanged == null) return;
    final pending = list
        .where(
          (r) => r.status == 'Pending' && r.isIncoming(widget.session.email),
        )
        .length;
    widget.onPendingRequestsChanged!(pending);
  }

  void _onInviteQueryChanged() {
    _debounce?.cancel();
    final query = _inviteController.text.trim();
    setState(() {
      if (query.length < 2) {
        _suggestions = [];
        _searching = false;
      }
    });
    if (query.length < 2) return;
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _searchInviteSuggestions(query),
    );
  }

  void _onFriendFilterChanged() {
    setState(() {});
  }

  Future<void> _searchInviteSuggestions(String query) async {
    setState(() => _searching = true);
    try {
      final results = await _api.searchFriends(widget.session.token, query);
      if (!mounted || query != _inviteController.text.trim()) return;
      setState(() => _suggestions = results);
    } on ApiException {
      if (!mounted || query != _inviteController.text.trim()) return;
      setState(() => _suggestions = []);
    } finally {
      if (mounted && query == _inviteController.text.trim()) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _sendRequest([String? identifier]) async {
    final target = (identifier ?? _inviteController.text).trim();
    if (target.isEmpty) {
      _showSnack(S.of(context).enterEmailOrIdentifier, isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _api.sendRequest(token: widget.session.token, identifier: target);
      if (!mounted) return;
      _showSnack(S.of(context).requestSent);
      _inviteController.clear();
      setState(() => _suggestions = []);
      await _fetchRequests();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).unableToSendRequest, isError: true);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _respondRequest(
    FriendRequestModel request,
    String status,
  ) async {
    setState(() => _sending = true);
    try {
      await _api.respondToRequest(
        token: widget.session.token,
        requestId: request.id,
        status: status,
      );
      if (!mounted) return;
      await _refreshAll();
      if (!mounted) return;
      _showSnack(
        status == 'Accepted'
            ? S.of(context).requestAccepted
            : S.of(context).friendRequestDeclined,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).actionFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _removeFriend(FriendModel friend) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).removeFriendTitle),
        content: Text(S.of(context).removeFriendWarning(friend.handle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(S.of(context).remove),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.deleteFriend(
        token: widget.session.token,
        identifier: friend.handle,
      );
      if (!mounted) return;
      await _fetchFriends();
      if (!mounted) return;
      _showSnack(S.of(context).friendRemoved);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).removeImpossible, isError: true);
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? theme.colorScheme.error : null,
      ),
    );
  }

  List<FriendRequestModel> _sortedRequests(
    Iterable<FriendRequestModel> requests,
  ) {
    final list = requests.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<FriendModel> get _filteredFriends {
    final query = _friendsFilterController.text.trim().toLowerCase();
    final friends = [..._friends];
    friends.sort((a, b) {
      final left = _friendSortLabel(a);
      final right = _friendSortLabel(b);
      return left.compareTo(right);
    });
    if (query.isEmpty) return friends;
    return friends.where((friend) {
      final handle = friend.handle.toLowerCase();
      final email = friend.email.toLowerCase();
      return handle.contains(query) || email.contains(query);
    }).toList();
  }

  String _friendSortLabel(FriendModel friend) {
    final handle = friend.handle.trim();
    return (handle.isNotEmpty ? handle : friend.email).toLowerCase();
  }

  List<_FriendListEntry> _buildFriendEntries(List<FriendModel> friends) {
    final entries = <_FriendListEntry>[];
    String? currentSection;
    for (final friend in friends) {
      final section = _friendSection(friend);
      if (section != currentSection) {
        entries.add(_FriendListEntry.header(section));
        currentSection = section;
      }
      entries.add(_FriendListEntry.friend(friend));
    }
    return entries;
  }

  String _friendSection(FriendModel friend) {
    final label = _friendSortLabel(friend).trim();
    if (label.isEmpty) return '#';
    final first = label.characters.first.toUpperCase();
    final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
    return isLetter ? first : '#';
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _sortedRequests(
      _requests.where((r) => r.isIncoming(widget.session.email)),
    );
    final outgoing = _sortedRequests(
      _requests.where((r) => !r.isIncoming(widget.session.email)),
    );
    final visibleFriends = _filteredFriends;
    final friendEntries = _buildFriendEntries(visibleFriends);

    return FiestaaaPageLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FiestaaaPageHeader(
            title: S.of(context).myFriends,
            subtitle: S.of(context).addContactsManageRequests,
            bottomSpacing: 12,
          ),
          _FriendsOverviewCard(
            friendCount: _friends.length,
            incomingCount: incoming.length,
            outgoingCount: outgoing.length,
          ),
          const SizedBox(height: 16),
          _FriendsTabs(
            controller: _tabController,
            pendingIncomingCount: incoming.length,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FriendsDirectoryTab(
                  filterController: _friendsFilterController,
                  query: _friendsFilterController.text.trim(),
                  totalFriendsCount: _friends.length,
                  filteredFriendsCount: visibleFriends.length,
                  loading: _loading,
                  error: _error,
                  entries: friendEntries,
                  onRefresh: _refreshAll,
                  onClearFilter: () => _friendsFilterController.clear(),
                  onRemove: _removeFriend,
                ),
                _RequestsTab(
                  loading: _loadingRequests,
                  error: _requestError,
                  incoming: incoming,
                  outgoing: outgoing,
                  userEmail: widget.session.email,
                  onRefresh: _refreshAll,
                  onAccept: (req) => _respondRequest(req, 'Accepted'),
                  onDecline: (req) => _respondRequest(req, 'Declined'),
                ),
                _AddFriendTab(
                  controller: _inviteController,
                  searching: _searching,
                  suggestions: _suggestions,
                  sending: _sending,
                  onRefresh: _refreshAll,
                  onSend: _sendRequest,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsOverviewCard extends StatelessWidget {
  const _FriendsOverviewCard({
    required this.friendCount,
    required this.incomingCount,
    required this.outgoingCount,
  });

  final int friendCount;
  final int incomingCount;
  final int outgoingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primarySoft = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.22 : 0.09,
    );
    final secondarySoft = theme.colorScheme.secondary.withValues(
      alpha: isDark ? 0.22 : 0.12,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: isDark ? 0.96 : 0.98),
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth > 560
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    icon: Icons.group_outlined,
                    value: '$friendCount',
                    label: S.of(context).friendsTab,
                    accentColor: theme.colorScheme.primary,
                    backgroundColor: primarySoft,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    icon: Icons.mark_email_unread_outlined,
                    value: '$incomingCount',
                    label: S.of(context).received,
                    accentColor: theme.colorScheme.primary,
                    backgroundColor: primarySoft,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    icon: Icons.outbox_outlined,
                    value: '$outgoingCount',
                    label: S.of(context).sent,
                    accentColor: theme.colorScheme.secondary,
                    backgroundColor: secondarySoft,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FriendsTabs extends StatelessWidget {
  const _FriendsTabs({
    required this.controller,
    required this.pendingIncomingCount,
  });

  final TabController controller;
  final int pendingIncomingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 390;
        final requestText = isCompact
            ? S.of(context).requestsShort
            : S.of(context).friendRequests;
        final addText = isCompact ? S.of(context).add : S.of(context).addFriend;
        final labelStyle = theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: isCompact ? 12 : null,
        );

        Widget tabText(String text) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          );
        }

        Widget requestLabel() {
          if (pendingIncomingCount <= 0) {
            return tabText(requestText);
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: tabText(requestText)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$pendingIncomingCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: isDark ? 0.92 : 0.9,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: controller,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            splashBorderRadius: BorderRadius.circular(18),
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.7,
            ),
            labelStyle: labelStyle,
            unselectedLabelStyle: labelStyle,
            tabs: [
              Tab(child: tabText(S.of(context).friendsTab)),
              Tab(child: requestLabel()),
              Tab(child: tabText(addText)),
            ],
          ),
        );
      },
    );
  }
}

class _FriendsDirectoryTab extends StatelessWidget {
  const _FriendsDirectoryTab({
    required this.filterController,
    required this.query,
    required this.totalFriendsCount,
    required this.filteredFriendsCount,
    required this.loading,
    required this.error,
    required this.entries,
    required this.onRefresh,
    required this.onClearFilter,
    required this.onRemove,
  });

  final TextEditingController filterController;
  final String query;
  final int totalFriendsCount;
  final int filteredFriendsCount;
  final bool loading;
  final String? error;
  final List<_FriendListEntry> entries;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearFilter;
  final ValueChanged<FriendModel> onRemove;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 28,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: _SectionPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.search_rounded,
                      title: S.of(context).searchFriends,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: filterController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: S.of(context).filterFriends,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: hasQuery
                            ? IconButton(
                                onPressed: onClearFilter,
                                icon: const Icon(Icons.close),
                                tooltip: S.of(context).close,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.group_outlined,
                          value: '$totalFriendsCount',
                          label: S.of(context).friendsTab,
                        ),
                        if (hasQuery)
                          _InfoPill(
                            icon: Icons.filter_alt_outlined,
                            value: '$filteredFriendsCount',
                            label: S.of(context).search,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 32),
                child: _StatePanel(
                  icon: Icons.refresh_rounded,
                  message: error!,
                  action: OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(S.of(context).retry),
                  ),
                ),
              ),
            )
          else if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 32),
                child: _StatePanel(
                  icon: hasQuery
                      ? Icons.search_off_rounded
                      : Icons.group_off_outlined,
                  message: hasQuery
                      ? S.of(context).noFriendsMatchSearch
                      : S.of(context).addFirstFriends,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = entries[index];
                  if (entry.isHeader) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        4,
                        index == 0 ? 0 : 16,
                        4,
                        8,
                      ),
                      child: Text(
                        entry.label!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FriendTile(
                      friend: entry.friend!,
                      onRemove: onRemove,
                    ),
                  );
                }, childCount: entries.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.loading,
    required this.error,
    required this.incoming,
    required this.outgoing,
    required this.userEmail,
    required this.onRefresh,
    required this.onAccept,
    required this.onDecline,
  });

  final bool loading;
  final String? error;
  final List<FriendRequestModel> incoming;
  final List<FriendRequestModel> outgoing;
  final String userEmail;
  final Future<void> Function() onRefresh;
  final ValueChanged<FriendRequestModel> onAccept;
  final ValueChanged<FriendRequestModel> onDecline;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 28,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          _SectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.mail_outline,
                  title: S.of(context).friendRequests,
                  trailing: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.mark_email_unread_outlined,
                      value: '${incoming.length}',
                      label: S.of(context).received,
                    ),
                    _InfoPill(
                      icon: Icons.outbox_outlined,
                      value: '${outgoing.length}',
                      label: S.of(context).sent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _StatePanel(
              icon: Icons.error_outline,
              message: error!,
              action: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(S.of(context).retry),
              ),
            )
          else if (incoming.isEmpty && outgoing.isEmpty)
            _StatePanel(
              icon: Icons.inbox_outlined,
              message: S.of(context).noRequestInProgress,
            )
          else ...[
            _RequestsBucket(
              title: S.of(context).received,
              icon: Icons.mark_email_unread_outlined,
              requests: incoming,
              userEmail: userEmail,
              incoming: true,
              onAccept: onAccept,
              onDecline: onDecline,
            ),
            const SizedBox(height: 12),
            _RequestsBucket(
              title: S.of(context).sent,
              icon: Icons.outbox_outlined,
              requests: outgoing,
              userEmail: userEmail,
              incoming: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddFriendTab extends StatelessWidget {
  const _AddFriendTab({
    required this.controller,
    required this.searching,
    required this.suggestions,
    required this.sending,
    required this.onRefresh,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool searching;
  final bool sending;
  final List<FriendSearchResult> suggestions;
  final Future<void> Function() onRefresh;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 28,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          _SectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.person_add_alt_1_outlined,
                  title: S.of(context).addFriend,
                ),
                const SizedBox(height: 10),
                Text(
                  S.of(context).addContactsManageRequests,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: sending ? null : (_) => onSend(),
                  decoration: InputDecoration(
                    labelText: S.of(context).emailOrIdentifierField,
                    hintText: S.of(context).emailOrIdentifierField,
                    prefixIcon: const Icon(Icons.alternate_email),
                    suffixIcon: hasText
                        ? IconButton(
                            onPressed: controller.clear,
                            icon: const Icon(Icons.close),
                            tooltip: S.of(context).close,
                          )
                        : null,
                  ),
                ),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: suggestions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        final title = suggestion.handle.isNotEmpty
                            ? '@${suggestion.handle}'
                            : suggestion.email;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: _AvatarCircle(
                            url: suggestion.avatarUrl,
                            fallbackText: suggestion.handle.isNotEmpty
                                ? suggestion.handle
                                : suggestion.email,
                            size: 40,
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            suggestion.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => onSend(
                            suggestion.handle.isNotEmpty
                                ? suggestion.handle
                                : suggestion.email,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sending ? null : () => onSend(),
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      sending
                          ? S.of(context).sending
                          : S.of(context).sendRequest,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsBucket extends StatelessWidget {
  const _RequestsBucket({
    required this.title,
    required this.icon,
    required this.requests,
    required this.userEmail,
    required this.incoming,
    this.onAccept,
    this.onDecline,
  });

  final String title;
  final IconData icon;
  final List<FriendRequestModel> requests;
  final String userEmail;
  final bool incoming;
  final ValueChanged<FriendRequestModel>? onAccept;
  final ValueChanged<FriendRequestModel>? onDecline;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
            trailing: _CountBadge(count: requests.length),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            Text(
              S.of(context).noRequest,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _RequestTile(
                  request: requests[index],
                  userEmail: userEmail,
                  incoming: incoming,
                  onAccept: onAccept,
                  onDecline: onDecline,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.userEmail,
    required this.incoming,
    this.onAccept,
    this.onDecline,
  });

  final FriendRequestModel request;
  final String userEmail;
  final bool incoming;
  final ValueChanged<FriendRequestModel>? onAccept;
  final ValueChanged<FriendRequestModel>? onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat.yMMMd(S.of(context).localeName);
    final handle = incoming ? request.senderHandle : request.receiverHandle;
    final email = incoming ? request.senderEmail : request.receiverEmail;
    final avatarUrl = incoming
        ? request.senderAvatarUrl
        : request.receiverAvatarUrl;
    final title = handle.isNotEmpty ? '@$handle' : email;
    final subtitle = incoming
        ? S
              .of(context)
              .receivedOn(formatter.format(request.createdAt.toLocal()))
        : S
              .of(context)
              .sentOnDate(formatter.format(request.createdAt.toLocal()));

    Widget trailingActions({required bool compact}) {
      if (incoming && onAccept != null && onDecline != null) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => onDecline!(request),
              child: Text(S.of(context).decline),
            ),
            ElevatedButton(
              onPressed: () => onAccept!(request),
              child: Text(S.of(context).accept),
            ),
          ],
        );
      }

      return Chip(
        label: Text(
          S.of(context).pending,
          style: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: theme.colorScheme.secondaryContainer,
      );
    }

    return _TileShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final actions = trailingActions(compact: compact);

          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            leading: _AvatarCircle(
              url: avatarUrl,
              fallbackText: handle.isNotEmpty ? handle : email,
              size: 42,
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
                if (compact) ...[const SizedBox(height: 10), actions],
              ],
            ),
            trailing: compact ? null : actions,
            isThreeLine: compact,
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onRemove});

  final FriendModel friend;
  final ValueChanged<FriendModel> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat.yMMMd(S.of(context).localeName);
    final title = friend.handle.isNotEmpty ? '@${friend.handle}' : friend.email;

    return _TileShell(
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        leading: _AvatarCircle(
          url: friend.avatarUrl,
          fallbackText: friend.handle.isNotEmpty ? friend.handle : friend.email,
          size: 42,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(friend.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              S
                  .of(context)
                  .friendSince(formatter.format(friend.since.toLocal())),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton<_FriendMenuAction>(
          onSelected: (action) {
            if (action == _FriendMenuAction.remove) {
              onRemove(friend);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<_FriendMenuAction>(
              value: _FriendMenuAction.remove,
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove_outlined,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Text(S.of(context).remove),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.82 : 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.94 : 0.96,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.9 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _SectionPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({this.url, this.fallbackText, this.size = 40});

  final String? url;
  final String? fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = (fallbackText ?? '').trim();
    final firstLetter = label.isEmpty
        ? '?'
        : label.characters.first.toUpperCase();
    final theme = Theme.of(context);
    final bg = theme.colorScheme.primary.withValues(alpha: 0.14);
    final fg = theme.colorScheme.primary;

    Widget placeholder() => CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Text(
        firstLetter,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.34),
      ),
    );

    if (url == null || url!.isEmpty) {
      return placeholder();
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder(),
        ),
      ),
    );
  }
}

class _FriendListEntry {
  const _FriendListEntry.header(this.label) : friend = null;

  const _FriendListEntry.friend(this.friend) : label = null;

  final String? label;
  final FriendModel? friend;

  bool get isHeader => label != null;
}
