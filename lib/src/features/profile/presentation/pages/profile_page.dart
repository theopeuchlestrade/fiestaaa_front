import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onSessionUpdated,
  });

  final SessionData session;
  final VoidCallback onLogout;
  final Future<void> Function(SessionData session)? onSessionUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ProfileApi();
  final _friendsApi = FriendsApi();
  Future<ProfileInfo>? _future;
  final _handleController = TextEditingController();
  bool _checkingHandle = false;
  bool? _handleAvailable;
  bool _updatingHandle = false;
  String? _handleStatus;
  List<FriendModel> _friends = [];
  bool _loadingFriends = true;
  String? _friendsError;
  final _friendSearchController = TextEditingController();
  List<FriendSearchResult> _friendSuggestions = [];
  bool _searchingFriends = false;
  bool _sendingFriendRequest = false;
  Timer? _friendSearchDebounce;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchProfile(widget.session.token);
    _friendSearchController.addListener(_onFriendQueryChanged);
    _loadFriends();
  }

  @override
  void dispose() {
    _handleController.dispose();
    _friendSearchDebounce?.cancel();
    _friendSearchController.dispose();
    _friendsApi.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _checkHandleAvailability() async {
    final handle = _handleController.text.trim();
    if (handle.isEmpty) {
      setState(() {
        _handleStatus = 'Renseignez un identifiant pour vérifier';
        _handleAvailable = null;
      });
      return;
    }

    setState(() {
      _checkingHandle = true;
      _handleStatus = null;
    });
    try {
      final available = await _api.checkHandleAvailability(handle);
      if (!mounted) return;
      setState(() {
        _handleAvailable = available;
        _handleStatus =
            available ? 'Identifiant disponible' : 'Identifiant déjà pris';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _handleAvailable = false;
        _handleStatus = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _handleAvailable = null;
        _handleStatus = 'Vérification impossible';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingHandle = false;
      });
    }
  }

  Future<void> _updateHandle(ProfileInfo profile) async {
    final handle = _handleController.text.trim();
    if (handle.isEmpty) {
      _showSnack('Merci de renseigner un identifiant', isError: true);
      return;
    }

    setState(() {
      _updatingHandle = true;
      _handleStatus = null;
    });
    try {
      final updated = await _api.updateHandle(
        token: widget.session.token,
        handle: handle,
      );
      if (!mounted) return;
      _handleController.text = updated.handle;
      setState(() {
        _future = Future.value(updated);
        _handleAvailable = null;
        _handleStatus = 'Identifiant mis à jour';
      });
      if (widget.onSessionUpdated != null) {
        await widget.onSessionUpdated!(
          widget.session.copyWith(handle: updated.handle),
        );
      }
      _showSnack('Identifiant mis à jour');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
      setState(() {
        _handleAvailable = false;
        _handleStatus = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack('Mise à jour impossible', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _updatingHandle = false;
      });
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loadingFriends = true;
      _friendsError = null;
    });
    try {
      final friends = await _friendsApi.fetchFriends(widget.session.token);
      if (!mounted) return;
      setState(() => _friends = friends);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _friendsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendsError = 'Impossible de charger vos amis.');
    } finally {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }
  }

  void _onFriendQueryChanged() {
    _friendSearchDebounce?.cancel();
    final query = _friendSearchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _friendSuggestions = [];
        _searchingFriends = false;
      });
      return;
    }
    _friendSearchDebounce =
        Timer(const Duration(milliseconds: 250), () => _searchFriends(query));
  }

  Future<void> _searchFriends(String query) async {
    setState(() {
      _searchingFriends = true;
    });
    try {
      final results =
          await _friendsApi.searchFriends(widget.session.token, query);
      if (!mounted) return;
      setState(() => _friendSuggestions = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendSuggestions = []);
    } finally {
      if (!mounted) return;
      setState(() => _searchingFriends = false);
    }
  }

  Future<void> _sendFriendRequest([String? identifier]) async {
    final target = (identifier ?? _friendSearchController.text).trim();
    if (target.isEmpty) {
      _showSnack('Renseignez un email ou identifiant', isError: true);
      return;
    }
    setState(() {
      _sendingFriendRequest = true;
    });
    try {
      await _friendsApi.sendRequest(
        token: widget.session.token,
        identifier: target,
      );
      if (!mounted) return;
      _showSnack('Demande d’ami envoyée');
      setState(() {
        _friendSearchController.clear();
        _friendSuggestions = [];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d’envoyer la demande', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _sendingFriendRequest = false);
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
      await _friendsApi.deleteFriend(
        token: widget.session.token,
        identifier: friend.handle,
      );
      if (!mounted) return;
      _showSnack('Ami retiré');
      await _loadFriends();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible de retirer cet ami', isError: true);
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
    return FiestaaaBackground(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mon profil',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gérez votre compte et vos invitations.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FutureBuilder<ProfileInfo>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        const Text('Impossible de charger votre profil'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _future = _api.fetchProfile(widget.session.token);
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    );
                  }

                  final profile = snapshot.data;
                  if (profile == null) {
                    return const Text('Profil introuvable');
                  }

                  if (_handleController.text.isEmpty) {
                    _handleController.text = profile.handle;
                  }

                  return Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      FiestaaaPalette.primary.withOpacity(0.14),
                                foregroundColor: FiestaaaPalette.primary,
                                  child: Text(
                                    profile.email.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  profile.email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'Token valide jusqu’au ${DateFormat.yMMMMd('fr_FR').format(profile.expiration)} ${DateFormat.Hm().format(profile.expiration)}',
                                ),
                                trailing: Chip(
                                  label: Text(
                                    'Connecté',
                                    style: TextStyle(
                                      color: FiestaaaPalette.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  backgroundColor:
                                      FiestaaaPalette.primary.withOpacity(0.12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Chip(
                                    avatar: const Icon(Icons.tag, size: 18),
                                    label: Text(profile.handle),
                                  ),
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: widget.onLogout,
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Se déconnecter'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.group_outlined,
                                      color: Colors.teal),
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
                                    onPressed:
                                        _loadingFriends ? null : _loadFriends,
                                    tooltip: 'Actualiser la liste',
                                    icon: const Icon(Icons.refresh),
                                  ),
                                  if (_loadingFriends)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _friendSearchController,
                                decoration: const InputDecoration(
                                  labelText: 'Rechercher par email ou identifiant',
                                  prefixIcon: Icon(Icons.person_add_alt_1),
                                ),
                              ),
                              if (_searchingFriends)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: LinearProgressIndicator(minHeight: 2),
                                )
                              else if (_friendSuggestions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _friendSuggestions.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final suggestion =
                                            _friendSuggestions[index];
                                        final handle = suggestion.handle;
                                        final email = suggestion.email;
                                        final label = handle.isNotEmpty
                                            ? '@$handle'
                                            : email;
                                        return ListTile(
                                          leading: const Icon(
                                              Icons.person_outline_outlined),
                                          title: Text(label),
                                          subtitle: Text(email),
                                          trailing: IconButton(
                                            onPressed: _sendingFriendRequest
                                                ? null
                                                : () => _sendFriendRequest(
                                                    handle.isNotEmpty
                                                        ? handle
                                                        : email),
                                            icon: const Icon(Icons.person_add),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _sendingFriendRequest
                                      ? null
                                      : _sendFriendRequest,
                                  icon: _sendingFriendRequest
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(_sendingFriendRequest
                                      ? 'Envoi...'
                                      : 'Envoyer une demande'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Ma liste d’amis',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (_loadingFriends)
                                const Center(
                                    child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(),
                                ))
                              else if (_friendsError != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _friendsError!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _loadFriends,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Réessayer'),
                                    ),
                                  ],
                                )
                              else if (_friends.isEmpty)
                                const Text(
                                  'Ajoutez vos premiers amis pour les inviter rapidement.',
                                  style: TextStyle(color: Colors.grey),
                                )
                              else
                                ..._friends.map(
                                  (friend) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.shade50,
                                      foregroundColor: Colors.teal.shade800,
                                      child: Text(
                                        friend.handle
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    title: Text('@${friend.handle}'),
                                    subtitle: Text(
                                      'Ami depuis ${DateFormat.yMMMMd('fr_FR').format(friend.since)}',
                                    ),
                                    trailing: IconButton(
                                      onPressed: () => _removeFriend(friend),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.edit_outlined,
                                      color: Colors.deepPurple),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Modifier mon identifiant',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  if (_checkingHandle || _updatingHandle)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _handleController,
                                enabled: !_updatingHandle,
                                decoration: InputDecoration(
                                  labelText: 'Ex: mango-forest-4832',
                                  helperText:
                                      'Utilisable à la connexion et pour les invitations.',
                                  prefixIcon: const Icon(Icons.alternate_email),
                                  suffixIcon: _handleAvailable == true
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : null,
                                ),
                              ),
                              if (_handleStatus != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _handleStatus!,
                                    style: TextStyle(
                                      color: _handleAvailable == false
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _checkingHandle
                                        ? null
                                        : _checkHandleAvailability,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Vérifier'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _updatingHandle
                                        ? null
                                        : () => _updateHandle(profile),
                                    icon: const Icon(Icons.save_outlined),
                                    label: Text(_updatingHandle
                                        ? 'En cours...'
                                        : 'Mettre à jour'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
