import 'package:fiestaaa_front/src/core/event_data_store.dart';
import 'package:fiestaaa_front/src/core/api_error_localizer.dart';
import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/event_module_header.dart';
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
    this.moduleLocations = const {},
    this.friendsApi,
    this.invitationsApi,
    required this.session,
    required this.eventId,
    required this.eventName,
    required this.ownerEmail,
    required this.eventReadOnly,
    this.realtimeStream,
    this.compactModal = false,
  });

  final Map<String, String> moduleLocations;
  final SessionData session;
  final InvitationsApi? invitationsApi;
  final FriendsApi? friendsApi;
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

  late final _api = widget.invitationsApi ?? InvitationsApi();
  late final _friendsApi = widget.friendsApi ?? FriendsApi();
  List<InvitationModel> _invitations = [];
  bool _loading = true;
  String? _error;

  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _showInviteForm = false;
  List<FriendModel> _friends = [];
  List<FriendRequestModel> _friendRequests = [];
  bool _sendingFriendAsk = false;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  bool _seenRealtimeReady = false;

  bool get _isOwner =>
      widget.session.email.toLowerCase() == widget.ownerEmail.toLowerCase();
  bool get _canMutate => _isOwner && !widget.eventReadOnly;

  @override
  void initState() {
    super.initState();
    if (EventDataStore.instance.canReuseProtected(
      widget.session.token,
      widget.eventId,
    )) {
      final saved = EventDataStore.instance.peek<List<InvitationModel>>(
        widget.session.token,
        widget.eventId,
        'participants',
      );
      if (saved != null) {
        _invitations = saved;
        _loading = false;
      }
    }

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
        oldWidget.session.token != widget.session.token ||
        oldWidget.session.email != widget.session.email ||
        oldWidget.session.publicId != widget.session.publicId) {
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
    if (type == 'realtime.ready') {
      if (!_seenRealtimeReady) {
        _seenRealtimeReady = true;
        if (EventDataStore.instance.applies(widget.session.token)) return;
      }
      EventDataStore.instance.observeRealtime(
        widget.session.token,
        widget.eventId,
        message,
        reconnect: true,
      );
    } else {
      EventDataStore.instance.observeRealtime(
        widget.session.token,
        widget.eventId,
        message,
      );
    }
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
      setState(
        () => _error = localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).unableToLoadInvitations,
        ),
      );
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
      setState(() => _showInviteForm = false);
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
      _showSnack(
        localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).actionFailed,
        ),
        isError: true,
      );
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
      _showSnack(
        localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).actionFailed,
        ),
        isError: true,
      );
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
      _showSnack(
        localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).actionFailed,
        ),
        isError: true,
      );
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
    final canAddFriend =
        !isSelf &&
        !_isFriendWith(identifier) &&
        !_hasPendingFriendRequestWith(identifier);
    final canRemove = _canMutate && !isEventOwner;
    if (isSelf && !canRemove) return null;
    return PopupMenuButton<String>(
      tooltip: betaText(
        context,
        'Actions du participant',
        'Participant actions',
      ),
      onSelected: (action) {
        if (action == 'friend') _sendFriendRequestForInvitation(invitation);
        if (action == 'remove') _deleteInvitation(invitation);
      },
      itemBuilder: (_) => [
        if (!isSelf && !canAddFriend)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              _isFriendWith(identifier)
                  ? betaText(context, 'Déjà amis', 'Already friends')
                  : betaText(
                      context,
                      'Demande d’amitié en attente',
                      'Friend request pending',
                    ),
            ),
          ),
        if (canAddFriend)
          PopupMenuItem(
            value: 'friend',
            enabled: !_sendingFriendAsk,
            child: Text(S.of(context).addAsFriend),
          ),
        if (canRemove)
          PopupMenuItem(
            value: 'remove',
            child: Text(
              betaText(context, 'Retirer l’invitation', 'Remove invitation'),
            ),
          ),
      ],
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
          EventModuleHeader(
            title: S.of(context).participants,
            eventName: widget.eventName,
            eventId: widget.eventId,
            locations: widget.moduleLocations,
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _showInviteForm = !_showInviteForm),
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(
                    betaText(context, 'Inviter une personne', 'Invite someone'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openInviteFriendsPage,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(S.of(context).inviteFriends),
                ),
              ],
            ),
            if (_showInviteForm) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _InviteForm(
                    emailController: _emailController,
                    onSubmit: _submitting ? null : _createInvitation,
                    submitting: _submitting,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
          if (_error != null && _invitations.isNotEmpty)
            Column(
              children: [
                Text(_error!),
                TextButton(
                  onPressed: () {
                    EventDataStore.instance.invalidateEvent(widget.eventId);
                    _fetch();
                  },
                  child: Text(S.of(context).retry),
                ),
              ],
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && _invitations.isEmpty)
            Column(
              children: [
                Text(_error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    EventDataStore.instance.invalidateEvent(widget.eventId);
                    _fetch();
                  },
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
    final theme = Theme.of(context);
    final accepted = _invitations
        .where((inv) => inv.status == 'Accepted')
        .toList();
    final waiting = _invitations
        .where((inv) => inv.status == 'Waiting')
        .toList();
    final declined = _invitations
        .where((inv) => inv.status == 'Declined')
        .toList();
    Widget section(
      String title,
      List<InvitationModel> values,
      IconData icon, {
      bool showHeading = true,
    }) => InvitationStatusSection(
      title: title,
      showHeading: showHeading,
      icon: icon,
      accentColor: theme.colorScheme.onSurface,
      invitations: values,
      ownerEmail: widget.ownerEmail,
      emptyLabel: S.of(context).noOneAcceptedYet,
      trailingBuilder: _invitationActions,
    );
    return [
      if (accepted.isNotEmpty)
        section(
          betaText(context, 'Confirmés', 'Confirmed'),
          accepted,
          Icons.people_outline,
        ),
      if (waiting.isNotEmpty)
        section(
          betaText(context, 'En attente de réponse', 'Awaiting a response'),
          waiting,
          Icons.schedule_outlined,
        ),
      if (declined.isNotEmpty)
        Card(
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              '${S.of(context).declinedSectionTitle} · ${declined.length}',
              style: theme.textTheme.titleSmall,
            ),
            children: [
              section(
                betaText(
                  context,
                  'Invitations refusées',
                  'Declined invitations',
                ),
                declined,
                Icons.person_off_outlined,
                showHeading: false,
              ),
            ],
          ),
        ),
    ];
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
          child: FilledButton.icon(
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
