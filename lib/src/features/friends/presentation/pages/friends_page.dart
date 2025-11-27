import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    required this.session,
    this.onPendingRequestsChanged,
  });

  final SessionData session;
  final ValueChanged<int>? onPendingRequestsChanged;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _api = FriendsApi();
  final _searchController = TextEditingController();
  Timer? _debounce;

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
    _searchController.addListener(_onQueryChanged);
    _refreshAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchFriends(),
      _fetchRequests(),
    ]);
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
      setState(() => _error = 'Impossible de charger vos amis.');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
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
      setState(() => _requestError = 'Impossible de charger vos demandes.');
    } finally {
      if (!mounted) return;
      setState(() => _loadingRequests = false);
    }
  }

  void _notifyPendingRequests(List<FriendRequestModel> list) {
    if (widget.onPendingRequestsChanged == null) return;
    final pending = list
        .where(
            (r) => r.status == 'Pending' && r.isIncoming(widget.session.email))
        .length;
    widget.onPendingRequestsChanged!(pending);
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await _api.searchFriends(widget.session.token, query);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } on ApiException {
      if (!mounted) return;
      setState(() => _suggestions = []);
    } finally {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest([String? identifier]) async {
    final target = (identifier ?? _searchController.text).trim();
    if (target.isEmpty) {
      _showSnack('Renseignez un email ou identifiant', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _api.sendRequest(token: widget.session.token, identifier: target);
      if (!mounted) return;
      _showSnack('Demande envoyée');
      _searchController.clear();
      setState(() => _suggestions = []);
      await _fetchRequests();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d’envoyer la demande', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
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
      await _fetchRequests();
      await _fetchFriends();
      _showSnack(
          status == 'Accepted' ? 'Demande acceptée' : 'Demande d’ami refusée');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Action impossible', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  Future<void> _removeFriend(FriendModel friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cet ami ?'),
        content: Text('Vous ne serez plus connecté à @${friend.handle}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Retirer'),
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
      _showSnack('Ami retiré');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Suppression impossible', isError: true);
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
    final incoming =
        _requests.where((r) => r.isIncoming(widget.session.email)).toList();
    final outgoing =
        _requests.where((r) => !r.isIncoming(widget.session.email)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amis'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SearchCard(
              controller: _searchController,
              searching: _searching,
              suggestions: _suggestions,
              sending: _sending,
              onSend: _sendRequest,
            ),
            const SizedBox(height: 16),
            _RequestsCard(
              incoming: incoming,
              outgoing: outgoing,
              loading: _loadingRequests,
              error: _requestError,
              userEmail: widget.session.email,
              onAccept: (req) => _respondRequest(req, 'Accepted'),
              onDecline: (req) => _respondRequest(req, 'Declined'),
            ),
            const SizedBox(height: 16),
            _FriendsList(
              friends: _friends,
              loading: _loading,
              error: _error,
              onRefresh: _fetchFriends,
              onRemove: _removeFriend,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.searching,
    required this.suggestions,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool searching;
  final bool sending;
  final List<FriendSearchResult> suggestions;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Ajouter un ami',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Email ou identifiant',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            if (searching)
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
                      final label = suggestion.handle.isNotEmpty
                          ? '@${suggestion.handle}'
                          : suggestion.email;
                      return ListTile(
                        leading: _AvatarCircle(url: suggestion.avatarUrl),
                        title: Text(label),
                        subtitle: Text(suggestion.email),
                        onTap: () => onSend(suggestion.handle.isNotEmpty
                            ? suggestion.handle
                            : suggestion.email),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
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
                label: Text(sending ? 'Envoi...' : 'Envoyer la demande'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsCard extends StatelessWidget {
  const _RequestsCard({
    required this.incoming,
    required this.outgoing,
    required this.loading,
    required this.error,
    required this.userEmail,
    this.onAccept,
    this.onDecline,
  });

  final List<FriendRequestModel> incoming;
  final List<FriendRequestModel> outgoing;
  final bool loading;
  final String? error;
  final String userEmail;
  final ValueChanged<FriendRequestModel>? onAccept;
  final ValueChanged<FriendRequestModel>? onDecline;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMMd('fr_FR');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Demandes d’amis',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
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
                ],
              )
            else if (incoming.isEmpty && outgoing.isEmpty)
              const Text(
                'Aucune demande en cours.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              _RequestSection(
                title: 'Reçues',
                requests: incoming,
                userEmail: userEmail,
                formatter: formatter,
                onAccept: onAccept,
                onDecline: onDecline,
              ),
              const SizedBox(height: 12),
              _RequestSection(
                title: 'Envoyées',
                requests: outgoing,
                userEmail: userEmail,
                formatter: formatter,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestSection extends StatelessWidget {
  const _RequestSection({
    required this.title,
    required this.requests,
    required this.formatter,
    required this.userEmail,
    this.onAccept,
    this.onDecline,
  });

  final String title;
  final List<FriendRequestModel> requests;
  final DateFormat formatter;
  final String userEmail;
  final ValueChanged<FriendRequestModel>? onAccept;
  final ValueChanged<FriendRequestModel>? onDecline;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Text('Aucune', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    return Column(
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
          final counterpartHandle =
              req.isIncoming(userEmail) ? req.senderHandle : req.receiverHandle;
          final counterpartEmail =
              req.isIncoming(userEmail) ? req.senderEmail : req.receiverEmail;
          final avatarUrl = req.isIncoming(userEmail)
              ? req.senderAvatarUrl
              : req.receiverAvatarUrl;
          final label = counterpartHandle.isNotEmpty
              ? '@$counterpartHandle'
              : counterpartEmail;
          final subtitle =
              '${req.isIncoming(userEmail) ? 'Reçue' : 'Envoyée'} le ${formatter.format(req.createdAt.toLocal())}';
          final isPending = req.status == 'Pending';

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                _AvatarCircle(url: avatarUrl, fallbackText: counterpartHandle),
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
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({
    required this.friends,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onRemove,
  });

  final List<FriendModel> friends;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<FriendModel> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Mes amis',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: loading ? null : () => onRefresh(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                ),
              ],
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
                    onPressed: () => onRefresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (friends.isEmpty)
              const Text(
                'Ajoutez vos premiers amis pour les inviter rapidement.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...friends.map(
                (friend) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _AvatarCircle(
                    url: friend.avatarUrl,
                    fallbackText: friend.handle,
                  ),
                  title: Text('@${friend.handle}'),
                  subtitle: Text(
                    'Ami depuis ${DateFormat.yMMMMd('fr_FR').format(friend.since)}',
                  ),
                  trailing: IconButton(
                    onPressed: () => onRemove(friend),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({this.url, this.fallbackText, this.size = 32});

  final String? url;
  final String? fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = (fallbackText ?? '')
        .trim()
        .characters
        .take(1)
        .toString()
        .toUpperCase();
    Widget placeholder() => CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade800,
          child: Text(
            letter.isNotEmpty ? letter : '?',
            style: const TextStyle(fontWeight: FontWeight.w800),
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
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      ),
    );
  }
}
