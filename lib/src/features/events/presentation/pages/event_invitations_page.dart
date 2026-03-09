import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
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
    required this.ownerEmail,
    required this.eventReadOnly,
    this.realtimeStream,
    this.compactModal = false,
  });

  final SessionData session;
  final int eventId;
  final String ownerEmail;
  final bool eventReadOnly;
  final Stream<Map<String, dynamic>>? realtimeStream;
  final bool compactModal;

  @override
  State<EventInvitationsPage> createState() => _EventInvitationsPageState();
}

class _EventInvitationsPageState extends State<EventInvitationsPage> {
  final _api = InvitationsApi();
  final _friendsApi = FriendsApi();
  List<InvitationModel> _invitations = [];
  bool _loading = true;
  String? _error;

  final _emailController = TextEditingController();
  bool _submitting = false;
  List<FriendModel> _friends = [];
  List<FriendRequestModel> _friendRequests = [];
  bool _loadingFriends = true;
  String? _friendsError;
  final _friendFilterController = TextEditingController();
  final Set<String> _selectedFriendHandles = {};
  bool _invitingFriends = false;
  bool _sendingFriendAsk = false;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  bool get _isOwner =>
      widget.session.email.toLowerCase() == widget.ownerEmail.toLowerCase();
  bool get _canMutate => _isOwner && !widget.eventReadOnly;

  @override
  void initState() {
    super.initState();
    _friendFilterController.addListener(() {
      setState(() {});
    });
    _fetch();
    _loadFriendsAndRequests();
    _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _api.dispose();
    _emailController.dispose();
    _friendFilterController.dispose();
    _friendsApi.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EventInvitationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    if (type == 'event.invitations.changed') {
      _fetch();
    }
  }

  Future<void> _loadFriendsAndRequests() async {
    setState(() {
      _loadingFriends = true;
      _friendsError = null;
    });
    try {
      final results = await Future.wait([
        _friendsApi.fetchFriends(widget.session.token),
        _friendsApi.fetchRequests(widget.session.token),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendModel>;
        _friendRequests = results[1] as List<FriendRequestModel>;
        _pruneSelectedFriendHandles(
          _buildInvitedIdentifiers(_invitations),
          _friends,
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _friendsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendsError = S.of(context).unableToLoadFriends);
    } finally {
      if (mounted) {
        setState(() => _loadingFriends = false);
      }
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _api.fetchEventInvitations(
        token: widget.session.token,
        eventId: widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _invitations = all
            .where((inv) => inv.eventId == widget.eventId)
            .toList();
        _pruneSelectedFriendHandles(
          _buildInvitedIdentifiers(_invitations),
          _friends,
        );
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = S.of(context).unableToLoadInvitations);
    } finally {
      if (mounted) {
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

  List<FriendModel> get _filteredFriends {
    final query = _friendFilterController.text.trim().toLowerCase();
    final invitedIdentifiers = _buildInvitedIdentifiers(_invitations);
    return _friends.where((friend) {
      final handle = friend.handle.toLowerCase();
      final email = friend.email.toLowerCase();
      if (invitedIdentifiers.contains(handle) ||
          invitedIdentifiers.contains(email)) {
        return false;
      }
      if (query.isEmpty) return true;
      return handle.contains(query) || email.contains(query);
    }).toList();
  }

  bool _identifierMatches(String identifier, String handle, String email) {
    final normalized = identifier.toLowerCase();
    return handle.toLowerCase() == normalized ||
        email.toLowerCase() == normalized;
  }

  Set<String> _buildInvitedIdentifiers(List<InvitationModel> invitations) {
    final identifiers = <String>{};
    for (final invitation in invitations) {
      identifiers.add(invitation.email.toLowerCase());
      final handle = invitation.handle?.trim();
      if (handle != null && handle.isNotEmpty) {
        identifiers.add(handle.toLowerCase());
      }
    }
    return identifiers;
  }

  void _pruneSelectedFriendHandles(
    Set<String> invitedIdentifiers,
    List<FriendModel> friends,
  ) {
    final friendsByHandle = <String, FriendModel>{
      for (final friend in friends) friend.handle.toLowerCase(): friend,
    };
    _selectedFriendHandles.removeWhere((handle) {
      final normalized = handle.toLowerCase();
      final friend = friendsByHandle[normalized];
      if (friend == null) return true;
      return invitedIdentifiers.contains(normalized) ||
          invitedIdentifiers.contains(friend.email.toLowerCase());
    });
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

  void _toggleFriendSelection(String handle) {
    setState(() {
      if (_selectedFriendHandles.contains(handle)) {
        _selectedFriendHandles.remove(handle);
      } else {
        _selectedFriendHandles.add(handle);
      }
    });
  }

  Future<void> _inviteSelectedFriends() async {
    if (_selectedFriendHandles.isEmpty || !_canMutate) return;
    setState(() => _invitingFriends = true);
    var successCount = 0;
    String? firstError;
    var deadlineExpired = false;
    // Capture localized string before async loop
    final creationFailedMsg = S.of(context).creationFailed;

    try {
      for (final handle in _selectedFriendHandles) {
        try {
          await _api.createInvitation(
            token: widget.session.token,
            eventId: widget.eventId,
            identifier: handle,
          );
          successCount++;
        } on ApiException catch (e) {
          firstError ??= e.message;
          if (e.statusCode == 410) {
            deadlineExpired = true;
            break;
          }
        } catch (_) {
          firstError ??= creationFailedMsg;
        }
      }
      if (!mounted) return;
      await _fetch();
      if (!mounted) return;
      setState(() {
        _selectedFriendHandles.clear();
      });
      if (deadlineExpired) {
        _showSnack(S.of(context).deadlineExpired, isError: true);
        return;
      }
      if (successCount > 0) {
        _showSnack(
          successCount == 1
              ? S.of(context).invitationSentToFriend
              : S.of(context).invitationsSentToFriends(successCount),
        );
      } else if (firstError != null) {
        _showSnack(firstError, isError: true);
      } else {
        _showSnack(S.of(context).noInvitationSent, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _invitingFriends = false);
      }
    }
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
        actions.add(_statusIcon(Icons.verified, Colors.teal));
      } else if (_hasPendingFriendRequestWith(identifier)) {
        actions.add(_statusIcon(Icons.hourglass_top, Colors.orange));
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _filteredFriends;

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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      S.of(context).eventFinishedReadOnly,
                      style: TextStyle(
                        color: Colors.orange.shade900,
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
            _FriendsInviteCard(
              loading: _loadingFriends,
              error: _friendsError,
              friends: filteredFriends,
              selectedHandles: _selectedFriendHandles,
              filterController: _friendFilterController,
              onToggle: _toggleFriendSelection,
              onInvite: _selectedFriendHandles.isEmpty || _invitingFriends
                  ? null
                  : _inviteSelectedFriends,
              inviting: _invitingFriends,
              onRefresh: _loadFriendsAndRequests,
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

    if (widget.compactModal) return content;

    return Scaffold(body: FiestaaaPageLayout(child: content));
  }

  List<Widget> _buildInvitationSections() {
    final sections = [
      (
        status: 'Waiting',
        title: S.of(context).waiting,
        emptyLabel: S.of(context).noWaitingInvitation,
        icon: Icons.hourglass_bottom,
        color: Colors.amber,
      ),
      (
        status: 'Accepted',
        title: S.of(context).acceptedSectionTitle,
        emptyLabel: S.of(context).noOneAcceptedYet,
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      (
        status: 'Declined',
        title: S.of(context).declinedSectionTitle,
        emptyLabel: S.of(context).noDeclineRecorded,
        icon: Icons.cancel,
        color: Colors.redAccent,
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

class _FriendsInviteCard extends StatelessWidget {
  const _FriendsInviteCard({
    required this.loading,
    required this.error,
    required this.friends,
    required this.selectedHandles,
    required this.filterController,
    required this.onToggle,
    required this.onInvite,
    required this.inviting,
    required this.onRefresh,
  });

  final bool loading;
  final String? error;
  final List<FriendModel> friends;
  final Set<String> selectedHandles;
  final TextEditingController filterController;
  final ValueChanged<String> onToggle;
  final Future<void> Function()? onInvite;
  final bool inviting;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = inviting
        ? S.of(context).sending
        : (selectedHandles.isEmpty
              ? S.of(context).invite
              : (selectedHandles.length == 1
                    ? S.of(context).inviteFriend
                    : S
                          .of(context)
                          .inviteFriendsCount(selectedHandles.length)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context).inviteFromFriends,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : () => onRefresh(),
                  tooltip: S.of(context).refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context).searchAndSelectFriends,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: filterController,
              decoration: InputDecoration(
                labelText: S.of(context).filterFriends,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(S.of(context).retry),
                  ),
                ],
              )
            else if (friends.isEmpty)
              Text(
                S.of(context).noFriendAvailable,
                style: const TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: friends
                    .map(
                      (friend) => FilterChip(
                        label: Text('@${friend.handle}'),
                        selected: selectedHandles.contains(friend.handle),
                        onSelected: (_) => onToggle(friend.handle),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onInvite == null ? null : () => onInvite!(),
                icon: inviting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
