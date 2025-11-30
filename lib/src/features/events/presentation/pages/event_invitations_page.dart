import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/invitations/presentation/widgets/invitation_status_section.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventInvitationsPage extends StatefulWidget {
  const EventInvitationsPage({
    super.key,
    required this.session,
    required this.eventId,
    required this.ownerEmail,
    this.realtimeStream,
  });

  final SessionData session;
  final int eventId;
  final String ownerEmail;
  final Stream<Map<String, dynamic>>? realtimeStream;

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
  Timer? _suggestionDebounce;
  List<InvitationSuggestionModel> _suggestions = [];
  bool _suggestionsLoading = false;
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

  @override
  void initState() {
    super.initState();
    if (_isOwner) {
      _emailController.addListener(_onEmailChanged);
    }
    _friendFilterController.addListener(() {
      setState(() {});
    });
    _fetch();
    _loadFriendsAndRequests();
    _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
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

  void _onEmailChanged() {
    if (!_isOwner) return;
    _suggestionDebounce?.cancel();
    final query = _emailController.text.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _suggestionsLoading = false;
      });
      return;
    }

    _suggestionDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadSuggestions(query);
    });
  }

  void _handleRealtime(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    final eventId = message['event_id'] ?? message['eventId'];
    if (eventId is int && eventId != widget.eventId) return;
    if (type == 'invitation_updated') {
      _fetch();
    }
  }

  Future<void> _loadSuggestions(String query) async {
    setState(() {
      _suggestionsLoading = true;
    });
    try {
      final results = await _api.fetchInvitationSuggestions(
        token: widget.session.token,
        eventId: widget.eventId,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _suggestionsLoading = false;
        });
      }
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
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _friendsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendsError = 'Impossible de charger vos amis.');
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
        _invitations =
            all.where((inv) => inv.eventId == widget.eventId).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Impossible de charger les invitations.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applySuggestion(InvitationSuggestionModel suggestion) {
    final value =
        suggestion.handle.isNotEmpty ? suggestion.handle : suggestion.email;
    _emailController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    setState(() {
      _suggestions = [];
    });
  }

  Future<void> _createInvitation() async {
    if (!_isOwner) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Identifiant requis', isError: true);
      return;
    }
    if (!email.contains('@') &&
        !RegExp(r'^[a-z0-9._-]{4,32}$').hasMatch(email)) {
      _showSnack('Identifiant invalide', isError: true);
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
      final successMessage = result.emailSent
          ? (result.message ?? 'Invitation envoyée par email')
          : 'Invitation créée';
      _showSnack(successMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 410) {
        _showSnack(
          'La date limite est dépassée, impossible d’inviter de nouvelles personnes.',
          isError: true,
        );
        await _fetch();
        return;
      }
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur lors de la création', isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteInvitation(InvitationModel invitation) async {
    if (!_isOwner) return;
    try {
      await _api.deleteInvitation(
        token: widget.session.token,
        eventId: invitation.eventId,
        email: invitation.email,
      );
      if (!mounted) return;
      await _fetch();
      _showSnack('Invitation supprimée');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur lors de la suppression', isError: true);
    }
  }

  List<FriendModel> get _filteredFriends {
    final query = _friendFilterController.text.trim().toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends
        .where((f) =>
            f.handle.toLowerCase().contains(query) ||
            f.email.toLowerCase().contains(query))
        .toList();
  }

  bool _identifierMatches(String identifier, String handle, String email) {
    final normalized = identifier.toLowerCase();
    return handle.toLowerCase() == normalized ||
        email.toLowerCase() == normalized;
  }

  bool _isFriendWith(String identifier) {
    return _friends
        .any((f) => _identifierMatches(identifier, f.handle, f.email));
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
    if (_selectedFriendHandles.isEmpty || !_isOwner) return;
    setState(() => _invitingFriends = true);
    var successCount = 0;
    try {
      for (final handle in _selectedFriendHandles) {
        try {
          await _api.createInvitation(
            token: widget.session.token,
            eventId: widget.eventId,
            identifier: handle,
          );
          successCount++;
        } catch (_) {
          // Ignore individual failures, we report a summary below.
        }
      }
      if (!mounted) return;
      await _fetch();
      setState(() {
        _selectedFriendHandles.clear();
      });
      if (successCount > 0) {
        _showSnack(
          successCount == 1
              ? 'Invitation envoyée à votre ami.'
              : 'Invitations envoyées à $successCount amis.',
        );
      } else {
        _showSnack('Aucune invitation envoyée', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _invitingFriends = false);
      }
    }
  }

  Future<void> _sendFriendRequestForInvitation(
      InvitationModel invitation) async {
    final identifier = (invitation.handle?.isNotEmpty == true
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
      _showSnack('Demande d’ami envoyée');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d’envoyer la demande', isError: true);
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
        actions.add(const Icon(Icons.verified, color: Colors.teal));
      } else if (_hasPendingFriendRequestWith(identifier)) {
        actions.add(const Icon(Icons.hourglass_top, color: Colors.orange));
      } else {
        actions.add(IconButton(
          onPressed: _sendingFriendAsk
              ? null
              : () => _sendFriendRequestForInvitation(invitation),
          icon: const Icon(Icons.person_add_alt_1),
          tooltip: 'Ajouter en ami',
        ));
      }
    }

    if (_isOwner && !isEventOwner) {
      actions.add(
        IconButton(
          onPressed: () => _deleteInvitation(invitation),
          icon: const Icon(Icons.delete),
          tooltip: 'Supprimer',
        ),
      );
    }

    if (actions.isEmpty) return null;
    return Wrap(
      spacing: 4,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_fetch(), _loadFriendsAndRequests()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (_isOwner) ...[
              _InviteForm(
                emailController: _emailController,
                onSubmit: _submitting ? null : _createInvitation,
                submitting: _submitting,
                suggestions: _suggestions,
                suggestionsLoading: _suggestionsLoading,
                onSuggestionSelected: _applySuggestion,
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
                    child: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_invitations.isEmpty)
              const Center(
                child: Text(
                    'Aucune invitation pour le moment. Ajoutez-en plus haut.'),
              )
            else
              ..._buildInvitationSections(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInvitationSections() {
    const sections = [
      (
        status: 'Waiting',
        title: 'En attente',
        emptyLabel: 'Aucun invité en attente de réponse.',
        icon: Icons.hourglass_bottom,
        color: Colors.amber,
      ),
      (
        status: 'Accepted',
        title: 'Acceptées',
        emptyLabel: 'Personne n’a encore accepté.',
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      (
        status: 'Declined',
        title: 'Refusées',
        emptyLabel: 'Aucun refus enregistré.',
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
    required this.suggestions,
    required this.suggestionsLoading,
    required this.onSuggestionSelected,
  });

  final TextEditingController emailController;
  final VoidCallback? onSubmit;
  final bool submitting;
  final List<InvitationSuggestionModel> suggestions;
  final bool suggestionsLoading;
  final ValueChanged<InvitationSuggestionModel> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMMd('fr_FR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inviter un utilisateur',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email ou identifiant',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        if (suggestionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  final handle = suggestion.handle.isNotEmpty
                      ? suggestion.handle
                      : 'compte-a-creer';
                  final title = '@$handle';
                  return ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: Text(title),
                    subtitle: Text(
                      'Invité le ${formatter.format(suggestion.lastInvitedAt.toLocal())}',
                    ),
                    onTap: () => onSuggestionSelected(suggestion),
                  );
                },
              ),
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
            label: Text(submitting ? 'Envoi...' : 'Envoyer l’invitation'),
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
    final selectionLabel = selectedHandles.isEmpty
        ? ''
        : selectedHandles.length == 1
            ? 'cet ami'
            : '${selectedHandles.length} amis';
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
                Text(
                  'Inviter depuis mes amis',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: loading ? null : () => onRefresh(),
                  tooltip: 'Rafraîchir',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Recherchez et sélectionnez plusieurs amis, puis envoyez une invitation groupée.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: filterController,
              decoration: const InputDecoration(
                labelText: 'Filtrer vos amis',
                prefixIcon: Icon(Icons.search),
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
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (friends.isEmpty)
              const Text(
                'Aucun ami disponible pour le moment.',
                style: TextStyle(color: Colors.grey),
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
                label: Text(
                  inviting
                      ? 'Envoi...'
                      : (selectionLabel.isEmpty
                          ? 'Inviter'
                          : 'Inviter $selectionLabel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
