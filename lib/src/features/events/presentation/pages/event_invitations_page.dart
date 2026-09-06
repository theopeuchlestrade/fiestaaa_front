import 'package:fiestaaa_front/src/core/presentation/widgets/realtime_status_banner.dart';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/invitations/presentation/widgets/invitation_status_section.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';

class EventInvitationsPage extends StatefulWidget {
  const EventInvitationsPage({
    super.key,
    required this.session,
    required this.eventId,
    required this.eventName,
    required this.ownerEmail,
    required this.eventReadOnly,
    this.realtimeStream,
    this.compactModal = false,
  });

  final SessionData session;
  final int eventId;
  final String eventName;
  final String ownerEmail;
  final bool eventReadOnly;
  final Stream<Map<String, dynamic>>? realtimeStream;
  final bool compactModal;

  @override
  State<EventInvitationsPage> createState() => _EventInvitationsPageState();
}

class _EventInvitationsPageState extends State<EventInvitationsPage> {
  final _refreshQueue = RefreshQueue();
  int _scopeGeneration = 0;

  final _api = InvitationsApi();
  final _friendsApi = FriendsApi();
  List<InvitationModel> _invitations = [];
  bool _loading = true;
  String? _error;

  final _emailController = TextEditingController();
  bool _submitting = false;
  List<FriendModel> _friends = [];
  List<FriendRequestModel> _friendRequests = [];
  bool _sendingFriendAsk = false;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  bool get _isOwner =>
      widget.session.email.toLowerCase() == widget.ownerEmail.toLowerCase();
  bool get _canMutate => _isOwner && !widget.eventReadOnly;

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadFriendsAndRequests();
    _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
  }

  @override
  void dispose() {
    _refreshQueue.dispose();
    _realtimeSub?.cancel();
    _api.dispose();
    _emailController.dispose();
    _friendsApi.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EventInvitationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.session.token != widget.session.token) {
      _scopeGeneration++;
      _invitations = [];
      _fetch();
      _loadFriendsAndRequests();
    }
    if (oldWidget.realtimeStream != widget.realtimeStream) {
      _realtimeSub?.cancel();
      _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
    }
  }

  void _handleRealtime(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    final eventId = message['event_id'];
    if (eventId is int && eventId != widget.eventId) return;
    if (type == 'realtime.ready') _loadFriendsAndRequests();
    if (type == 'event.invitations.changed' || type == 'realtime.ready') {
      _fetch();
    }
  }

  Future<void> _loadFriendsAndRequests() => _refreshQueue.run(
    '_loadFriendsAndRequests',
    () => _loadFriendsAndRequestsOnce(),
  );

  Future<void> _loadFriendsAndRequestsOnce() async {
    if (!mounted) return;
    final requestScope = (
      _scopeGeneration,
      widget.session.token,
      widget.eventId,
    );
    try {
      final results = await Future.wait([
        _friendsApi.fetchFriends(widget.session.token),
        _friendsApi.fetchRequests(widget.session.token),
      ]);
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() {
        _friends = results[0] as List<FriendModel>;
        _friendRequests = results[1] as List<FriendRequestModel>;
      });
    } on ApiException {
      // Friend relationship badges are secondary here.
    } catch (_) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      // Ignore and keep invitation management available.
    }
  }

  Future<void> _fetch() => _refreshQueue.run('_fetch', () => _fetchOnce());

  Future<void> _fetchOnce() async {
    if (!mounted) return;
    final requestScope = (
      _scopeGeneration,
      widget.session.token,
      widget.eventId,
    );
    setState(() {
      _loading = _invitations.isEmpty;
      _error = null;
    });
    try {
      final all = await _api.fetchEventInvitations(
        token: widget.session.token,
        eventId: widget.eventId,
      );
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() {
        _invitations = all
            .where((inv) => inv.eventId == widget.eventId)
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() => _error = S.of(context).unableToLoadInvitations);
    } finally {
      if (mounted &&
          requestScope ==
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createInvitation() async {
    if (!_canMutate) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(S.of(context).identifierRequired, isError: true);
      return;
    }
    if (!email.contains('@') &&
        !RegExp(r'^[a-z0-9._-]{4,32}$').hasMatch(email)) {
      _showSnack(S.of(context).invalidIdentifier, isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _api.createInvitation(
        token: widget.session.token,
        eventId: widget.eventId,
        identifier: email,
      );
      if (!mounted) return;
      _emailController.clear();
      await _fetch();
      if (!mounted) return;
      final successMessage = result.emailSent
          ? (result.message ?? S.of(context).invitationSentByEmail)
          : S.of(context).invitationCreated;
      _showSnack(successMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 410) {
        _showSnack(S.of(context).deadlineExpired, isError: true);
        await _fetch();
        return;
      }
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).creationFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteInvitation(InvitationModel invitation) async {
    if (!_canMutate) return;
    try {
      await _api.deleteInvitation(
        token: widget.session.token,
        eventId: invitation.eventId,
        email: invitation.email,
        invitationId: invitation.invitationId,
      );
      if (!mounted) return;
      await _fetch();
      if (!mounted) return;
      _showSnack(S.of(context).invitationDeleted);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).deleteInvitationError, isError: true);
    }
  }

  bool _identifierMatches(String identifier, String handle, String email) {
    final normalized = identifier.toLowerCase();
    return handle.toLowerCase() == normalized ||
        email.toLowerCase() == normalized;
  }

  bool _isFriendWith(String identifier) {
    return _friends.any(
      (f) => _identifierMatches(identifier, f.handle, f.email),
    );
  }

  bool _hasPendingFriendRequestWith(String identifier) {
    return _friendRequests.any((req) {
      if (req.status != 'Pending') return false;
      final incoming = req.isIncoming(widget.session.email);
      final handle = incoming ? req.senderHandle : req.receiverHandle;
      final email = incoming ? req.senderEmail : req.receiverEmail;
      return _identifierMatches(identifier, handle, email);
    });
  }

  Widget _statusIcon(IconData icon, Color color) {
    return SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Center(child: Icon(icon, color: color)),
    );
  }

  Future<void> _openInviteFriendsPage() async {
    if (!_canMutate) return;
    final invitedCount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          body: FriendsPage(
            session: widget.session,
            realtimeStream: widget.realtimeStream,
            inviteFlow: FriendsPageInviteFlow(
              eventId: widget.eventId,
              eventName: widget.eventName,
            ),
          ),
        ),
      ),
    );

    if (!mounted || invitedCount == null || invitedCount <= 0) return;
    await _fetch();
    if (!mounted) return;
    _showSnack(
      invitedCount == 1
          ? S.of(context).invitationSentToFriend
          : S.of(context).invitationsSentToFriends(invitedCount),
    );
  }

  Future<void> _sendFriendRequestForInvitation(
    InvitationModel invitation,
  ) async {
    final identifier =
        (invitation.handle?.isNotEmpty == true
                ? invitation.handle!
                : invitation.email)
            .trim();
    if (identifier.isEmpty || _isFriendWith(identifier)) return;

    setState(() => _sendingFriendAsk = true);
    try {
      await _friendsApi.sendRequest(
        token: widget.session.token,
        identifier: identifier,
      );
      if (!mounted) return;
      await _loadFriendsAndRequests();
      if (!mounted) return;
      _showSnack(S.of(context).friendRequestSentSuccess);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).unableToSendRequest, isError: true);
    } finally {
      if (mounted) {
        setState(() => _sendingFriendAsk = false);
      }
    }
  }

  Widget? _invitationActions(InvitationModel invitation) {
    final identifier = invitation.handle?.isNotEmpty == true
        ? invitation.handle!
        : invitation.email;
    final isSelf =
        invitation.email.toLowerCase() == widget.session.email.toLowerCase();
    final isEventOwner =
        invitation.email.toLowerCase() == widget.ownerEmail.toLowerCase();

    final actions = <Widget>[];

    if (!isSelf) {
      if (_isFriendWith(identifier)) {
        actions.add(
          _statusIcon(
            Icons.verified,
            Theme.of(
              context,
            ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.info).foreground,
          ),
        );
      } else if (_hasPendingFriendRequestWith(identifier)) {
        actions.add(
          _statusIcon(
            Icons.hourglass_top,
            Theme.of(
              context,
            ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.warning).foreground,
          ),
        );
      } else {
        actions.add(
          IconButton(
            onPressed: _sendingFriendAsk
                ? null
                : () => _sendFriendRequestForInvitation(invitation),
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: S.of(context).addAsFriend,
          ),
        );
      }
    }

    if (_canMutate && !isEventOwner) {
      actions.add(
        IconButton(
          onPressed: () => _deleteInvitation(invitation),
          icon: const Icon(Icons.delete),
          tooltip: S.of(context).delete,
        ),
      );
    }

    if (actions.isEmpty) return null;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
  }

  void _showSnack(String text, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? scheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warningStyle = Theme.of(
      context,
    ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.warning);

    final content = RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_fetch(), _loadFriendsAndRequests()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: widget.compactModal,
        padding: EdgeInsets.zero,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FiestaaaPageHeader(title: S.of(context).invitations),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (widget.eventReadOnly) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warningStyle.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: warningStyle.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: warningStyle.foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      S.of(context).eventFinishedReadOnly,
                      style: TextStyle(
                        color: warningStyle.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_canMutate) ...[
            _InviteForm(
              emailController: _emailController,
              onSubmit: _submitting ? null : _createInvitation,
              submitting: _submitting,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openInviteFriendsPage,
                icon: const Icon(Icons.group_add_outlined),
                label: Text(S.of(context).inviteFriends),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Column(
              children: [
                Text(_error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _fetch,
                  child: Text(S.of(context).retry),
                ),
              ],
            )
          else if (_invitations.isEmpty)
            Center(child: Text(S.of(context).noInvitationForNow))
          else
            ..._buildInvitationSections(),
        ],
      ),
    );

    final realtimeContent = RealtimeStatusBanner(
      stream: widget.realtimeStream,
      child: content,
    );
    if (widget.compactModal) return realtimeContent;

    return Scaffold(body: FiestaaaPageLayout(child: realtimeContent));
  }

  List<Widget> _buildInvitationSections() {
    final scheme = Theme.of(context).colorScheme;
    final sections = [
      (
        status: 'Waiting',
        title: S.of(context).waiting,
        emptyLabel: S.of(context).noWaitingInvitation,
        icon: Icons.hourglass_bottom,
        color: scheme.fiestaaaStatus(FiestaaaStatusTone.warning).foreground,
      ),
      (
        status: 'Accepted',
        title: S.of(context).acceptedSectionTitle,
        emptyLabel: S.of(context).noOneAcceptedYet,
        icon: Icons.check_circle,
        color: scheme.fiestaaaStatus(FiestaaaStatusTone.success).foreground,
      ),
      (
        status: 'Declined',
        title: S.of(context).declinedSectionTitle,
        emptyLabel: S.of(context).noDeclineRecorded,
        icon: Icons.cancel,
        color: scheme.fiestaaaStatus(FiestaaaStatusTone.danger).foreground,
      ),
    ];

    return sections
        .map(
          (section) => InvitationStatusSection(
            title: section.title,
            icon: section.icon,
            accentColor: section.color,
            invitations: _invitations
                .where((inv) => inv.status == section.status)
                .toList(),
            ownerEmail: widget.ownerEmail,
            emptyLabel: section.emptyLabel,
            trailingBuilder: _invitationActions,
          ),
        )
        .toList();
  }
}

class _InviteForm extends StatelessWidget {
  const _InviteForm({
    required this.emailController,
    required this.onSubmit,
    required this.submitting,
  });

  final TextEditingController emailController;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).inviteUser,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: S.of(context).emailOrIdentifier,
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(
              submitting ? S.of(context).sending : S.of(context).sendInvitation,
            ),
          ),
        ),
      ],
    );
  }
}
