import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyInvitationsPage extends StatefulWidget {
  const MyInvitationsPage({
    super.key,
    required this.session,
    this.onOpenEvent,
  });

  final SessionData session;
  final void Function(int eventId)? onOpenEvent;

  @override
  State<MyInvitationsPage> createState() => _MyInvitationsPageState();
}

class _MyInvitationsPageState extends State<MyInvitationsPage> {
  final _api = InvitationsApi();
  final _friendsApi = FriendsApi();
  List<InvitationModel> _invitations = [];
  List<FriendRequestModel> _friendRequests = [];
  bool _loadingInvitations = true;
  bool _loadingFriendRequests = true;
  String? _invitationError;
  String? _friendRequestsError;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _api.dispose();
    _friendsApi.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchEventInvitations(),
      _fetchFriendRequests(),
    ]);
  }

  Future<void> _fetchEventInvitations() async {
    setState(() {
      _loadingInvitations = true;
      _invitationError = null;
    });
    try {
      final data = await _api.fetchMyInvitations(widget.session.token);
      if (!mounted) return;
      setState(() {
        _invitations = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _invitationError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _invitationError = S.of(context).unableToLoadInvitations);
    } finally {
      if (mounted) {
        setState(() => _loadingInvitations = false);
      }
    }
  }

  Future<void> _fetchFriendRequests() async {
    setState(() {
      _loadingFriendRequests = true;
      _friendRequestsError = null;
    });
    try {
      final data = await _friendsApi.fetchRequests(widget.session.token);
      if (!mounted) return;
      setState(() {
        _friendRequests = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _friendRequestsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _friendRequestsError = S.of(context).unableToLoadRequests);
    } finally {
      if (mounted) {
        setState(() => _loadingFriendRequests = false);
      }
    }
  }

  Future<void> _respond(InvitationModel invitation, String status) async {
    try {
      await _api.respondInvitation(
        token: widget.session.token,
        eventId: invitation.eventId,
        status: status,
      );
      if (!mounted) return;
      _showSnack(
        status == 'Accepted'
            ? S.of(context).invitationAccepted
            : S.of(context).invitationDeclined,
      );
      await _fetchEventInvitations();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 410) {
        _showSnack(S.of(context).invitationExpired, isError: true);
        await _fetchEventInvitations();
        return;
      }
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).actionFailed, isError: true);
    }
  }

  Future<void> _respondFriendRequest(
    FriendRequestModel request,
    String status,
  ) async {
    try {
      await _friendsApi.respondToRequest(
        token: widget.session.token,
        requestId: request.id,
        status: status,
      );
      if (!mounted) return;
      await _fetchFriendRequests();
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
    }
  }

  Future<void> _confirmLeave(InvitationModel invitation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).leaveEventTitle),
        content: Text(
          S.of(context).leaveEventWarning(invitation.eventName ?? S.of(context).fiestaaa),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.of(context).leaveEvent),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _respond(invitation, 'Declined');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Accepted':
        return S.of(context).accepted;
      case 'Declined':
        return S.of(context).declined;
      case 'Expired':
        return S.of(context).expired;
      case 'Waiting':
        return S.of(context).pending;
      default:
        return status;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green.shade800;
      case 'Declined':
        return Colors.grey.shade800;
      case 'Expired':
        return Colors.grey.shade700;
      case 'Waiting':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green.shade100;
      case 'Declined':
        return Colors.grey.shade200;
      case 'Expired':
        return Colors.grey.shade100;
      case 'Waiting':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Widget _buildInvitationActions(InvitationModel invitation,
      {required bool compact}) {
    if (invitation.status == 'Waiting') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: compact ? WrapAlignment.start : WrapAlignment.end,
        children: [
          TextButton(
            onPressed: () => _respond(invitation, 'Declined'),
            child: Text(S.of(context).decline),
          ),
          ElevatedButton(
            onPressed: () => _respond(invitation, 'Accepted'),
            child: Text(S.of(context).accept),
          ),
        ],
      );
    }

    if (invitation.status == 'Accepted') {
      return TextButton.icon(
        onPressed: () => _confirmLeave(invitation),
        icon: const Icon(Icons.logout),
        style: TextButton.styleFrom(
          foregroundColor: Colors.red.shade700,
        ),
        label: Text(S.of(context).leaveEvent),
      );
    }

    return Chip(
      label: Text(
        _statusLabel(invitation.status),
        style: TextStyle(
          color: _statusTextColor(invitation.status),
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: _statusBackgroundColor(invitation.status),
    );
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: FiestaaaPageLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BackButton(),
              ),
              const SizedBox(height: 4),
              FiestaaaPageHeader(
                title: S.of(context).myInvitations,
                bottomSpacing: 8,
              ),
              TabBar(
                tabs: [
                  Tab(text: S.of(context).fiestaaaTab),
                  Tab(text: S.of(context).friendsTab),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEventInvitationsTab(),
                    _buildFriendRequestsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventInvitationsTab() {
    return RefreshIndicator(
      onRefresh: _fetchEventInvitations,
      displacement: 28,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          if (_loadingInvitations)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_invitationError != null)
            Column(
              children: [
                Text(_invitationError!),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _fetchEventInvitations,
                  icon: const Icon(Icons.refresh),
                  label: Text(S.of(context).retry),
                ),
              ],
            )
          else if (_invitations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(S.of(context).noPendingInvitation),
              ),
            )
          else
            ..._invitations.map(
              (inv) => Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onOpenEvent != null &&
                          inv.status == 'Accepted'
                      ? () => widget.onOpenEvent!(inv.eventId)
                      : null,
                  splashColor:
                      FiestaaaPalette.primary.withValues(alpha: 0.12),
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 420;
                        final actions =
                            _buildInvitationActions(inv, compact: isCompact);
                        final subtitle = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context).receivedOn(
                                DateFormat.yMMMMd(Localizations.localeOf(context).toString())
                                    .format(inv.dateInvi),
                              ),
                            ),
                            if (isCompact) ...[
                              const SizedBox(height: 8),
                              actions,
                            ],
                          ],
                        );

                        return ListTile(
                          title: Text(
                            inv.eventName ?? '${S.of(context).fiestaaa} #${inv.eventId}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle,
                          leading: Icon(
                            Icons.mail_outline,
                            color: inv.status == 'Accepted'
                                ? Colors.green
                                : inv.status == 'Declined'
                                    ? Colors.redAccent
                                    : inv.status == 'Expired'
                                        ? Colors.grey
                                        : FiestaaaPalette.primary,
                          ),
                          trailing: isCompact ? null : actions,
                          isThreeLine: isCompact,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsTab() {
    final incoming = _friendRequests
        .where((req) => req.isIncoming(widget.session.email))
        .toList();
    final outgoing = _friendRequests
        .where((req) => !req.isIncoming(widget.session.email))
        .toList();

    return RefreshIndicator(
      onRefresh: _fetchFriendRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              S.of(context).friendRequests,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_loadingFriendRequests)
            const Center(child: CircularProgressIndicator())
          else if (_friendRequestsError != null)
            Column(
              children: [
                Text(_friendRequestsError!),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _fetchFriendRequests,
                  icon: const Icon(Icons.refresh),
                  label: Text(S.of(context).retry),
                ),
              ],
            )
          else if (incoming.isEmpty && outgoing.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(S.of(context).noRequestForNow),
              ),
            )
          else ...[
            _FriendRequestsSection(
              title: S.of(context).received,
              requests: incoming,
              onAccept: (req) => _respondFriendRequest(req, 'Accepted'),
              onDecline: (req) => _respondFriendRequest(req, 'Declined'),
              incoming: true,
            ),
            const SizedBox(height: 12),
            _FriendRequestsSection(
              title: S.of(context).sent,
              requests: outgoing,
            ),
          ],
        ],
      ),
    );
  }
}

class _FriendRequestsSection extends StatelessWidget {
  const _FriendRequestsSection({
    required this.title,
    required this.requests,
    this.onAccept,
    this.onDecline,
    this.incoming = false,
  });

  final String title;
  final List<FriendRequestModel> requests;
  final ValueChanged<FriendRequestModel>? onAccept;
  final ValueChanged<FriendRequestModel>? onDecline;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.of(context).nothingForNow,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...requests.map((req) {
              final isPending = req.status == 'Pending';
              final counterpartHandle =
                  incoming ? req.senderHandle : req.receiverHandle;
              final counterpartEmail =
                  incoming ? req.senderEmail : req.receiverEmail;
              final label = counterpartHandle.isNotEmpty
                  ? '@$counterpartHandle'
                  : counterpartEmail;
                  
              final dateStr = DateFormat.yMMMMd(Localizations.localeOf(context).toString())
                  .format(req.createdAt.toLocal());
              final subtitle = incoming
                  ? S.of(context).receivedOn(dateStr)
                  : S.of(context).sentOn(dateStr);
                  
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt_1),
                title: Text(label),
                subtitle: Text(subtitle),
                trailing: isPending && onAccept != null && onDecline != null
                    ? Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => onDecline!(req),
                            child: Text(S.of(context).decline),
                          ),
                          ElevatedButton(
                            onPressed: () => onAccept!(req),
                            child: Text(S.of(context).accept),
                          ),
                        ],
                      )
                    : Chip(
                        label: Text(
                          _statusLabel(context, req.status),
                          style: TextStyle(
                            color: req.status == 'Accepted'
                                ? Colors.green.shade800
                                : req.status == 'Declined'
                                    ? Colors.grey.shade800
                                    : Colors.orange.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: req.status == 'Accepted'
                            ? Colors.green.shade100
                            : req.status == 'Declined'
                                ? Colors.grey.shade200
                                : Colors.orange.shade100,
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'Accepted':
        return S.of(context).accepted;
      case 'Declined':
        return S.of(context).declined;
      case 'Pending':
        return S.of(context).pending;
      default:
        return status;
    }
  }
}
