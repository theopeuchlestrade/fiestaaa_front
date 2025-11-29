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
      setState(
          () => _invitationError = 'Impossible de charger vos invitations.');
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
          _friendRequestsError = 'Impossible de charger vos demandes d’ami.');
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
        status == 'Accepted' ? 'Invitation acceptée' : 'Invitation refusée',
      );
      await _fetchEventInvitations();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Action impossible', isError: true);
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
      _showSnack(
        status == 'Accepted' ? 'Demande acceptée' : 'Demande d’ami refusée',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Action impossible', isError: true);
    }
  }

  Future<void> _confirmLeave(InvitationModel invitation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter cet événement ?'),
        content: Text(
          'Vous êtes actuellement inscrit. Quitter l’événement retirera vos engagements pour ${invitation.eventName ?? 'cet évènement'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _respond(invitation, 'Declined');
    }
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
        appBar: AppBar(
          title: const Text('Mes invitations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Événements'),
              Tab(text: 'Amis'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEventInvitationsTab(),
            _buildFriendRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInvitationsTab() {
    return FiestaaaBackground(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: RefreshIndicator(
        onRefresh: _fetchEventInvitations,
        displacement: 28,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
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
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_invitations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Aucune invitation en attente.'),
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
                    onTap: widget.onOpenEvent == null
                        ? null
                        : () => widget.onOpenEvent!(inv.eventId),
                    splashColor:
                        FiestaaaPalette.primary.withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title:
                            Text(inv.eventName ?? 'Évènement #${inv.eventId}'),
                        subtitle: Text(
                          'Reçu le ${DateFormat.yMMMMd('fr_FR').format(inv.dateInvi)}',
                        ),
                        leading: Icon(
                          Icons.mail_outline,
                          color: inv.status == 'Accepted'
                              ? Colors.green
                              : inv.status == 'Declined'
                                  ? Colors.redAccent
                                  : FiestaaaPalette.primary,
                        ),
                        trailing: inv.status == 'Waiting'
                            ? Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => _respond(inv, 'Declined'),
                                    child: const Text('Refuser'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _respond(inv, 'Accepted'),
                                    child: const Text('Accepter'),
                                  ),
                                ],
                              )
                            : inv.status == 'Accepted'
                                ? TextButton.icon(
                                    onPressed: () => _confirmLeave(inv),
                                    icon: const Icon(Icons.logout),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                    label: const Text('Quitter'),
                                  )
                                : Chip(
                                    label: Text(
                                      inv.status,
                                      style: TextStyle(
                                        color: inv.status == 'Accepted'
                                            ? Colors.green.shade800
                                            : inv.status == 'Declined'
                                                ? Colors.grey.shade800
                                                : Colors.orange.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: inv.status == 'Accepted'
                                        ? Colors.green.shade100
                                        : inv.status == 'Declined'
                                            ? Colors.grey.shade200
                                            : Colors.orange.shade100,
                                  ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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

    return FiestaaaBackground(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: RefreshIndicator(
        onRefresh: _fetchFriendRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Demandes d’amis',
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
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (incoming.isEmpty && outgoing.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucune demande pour le moment.'),
                ),
              )
            else ...[
              _FriendRequestsSection(
                title: 'Reçues',
                requests: incoming,
                onAccept: (req) => _respondFriendRequest(req, 'Accepted'),
                onDecline: (req) => _respondFriendRequest(req, 'Declined'),
                incoming: true,
              ),
              const SizedBox(height: 12),
              _FriendRequestsSection(
                title: 'Envoyées',
                requests: outgoing,
              ),
            ],
          ],
        ),
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
              const Expanded(
                child: Text(
                  'Rien pour le moment',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final formatter = DateFormat.yMMMMd('fr_FR');
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
              final subtitle = incoming
                  ? 'Reçue le ${formatter.format(req.createdAt.toLocal())}'
                  : 'Envoyée le ${formatter.format(req.createdAt.toLocal())}';
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
                            child: const Text('Refuser'),
                          ),
                          ElevatedButton(
                            onPressed: () => onAccept!(req),
                            child: const Text('Accepter'),
                          ),
                        ],
                      )
                    : Chip(
                        label: Text(
                          req.status,
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
}
