import 'package:file_selector/file_selector.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
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
  Future<ProfileInfo>? _future;
  final _handleController = TextEditingController();
  bool _checkingHandle = false;
  bool? _handleAvailable;
  bool _updatingHandle = false;
  bool _deletingAccount = false;
  String? _handleStatus;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchProfile(widget.session.token);
  }

  @override
  void dispose() {
    _handleController.dispose();
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
      if (mounted) {
        setState(() {
          _checkingHandle = false;
        });
      }
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
      if (mounted) {
        setState(() {
          _updatingHandle = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
            'Cette action est irréversible. Toutes vos données seront définitivement supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deletingAccount = true;
    });

    try {
      await _api.deleteAccount(token: widget.session.token);
      if (!mounted) return;
      _showSnack('Compte supprimé');
      widget.onLogout();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Suppression impossible', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
      }
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

  Future<void> _pickAndUploadAvatar(ProfileInfo profile) async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final sizeMb = bytes.length / (1024 * 1024);
    if (sizeMb > 1.5) {
      _showSnack('Image trop lourde (max 1.5 Mo)', isError: true);
      return;
    }
    setState(() => _updatingHandle = true);
    try {
      final updated = await _api.uploadAvatar(
        token: widget.session.token,
        filename: file.name.isNotEmpty ? file.name : 'avatar.jpg',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _future = Future.value(updated);
      });
      if (widget.onSessionUpdated != null) {
        await widget.onSessionUpdated!(
          widget.session.copyWith(
            handle: updated.handle,
          ),
        );
      }
      _showSnack('Photo mise à jour');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Upload impossible', isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingHandle = false);
      }
    }
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
                                  radius: 26,
                                  backgroundColor:
                                      FiestaaaPalette.primary
                                          .withValues(alpha: 0.14),
                                  foregroundColor: FiestaaaPalette.primary,
                                  backgroundImage: profile.avatarUrl == null
                                      ? null
                                      : NetworkImage(profile.avatarUrl!),
                                  child: profile.avatarUrl == null
                                      ? Text(
                                          profile.email
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : null,
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
                                  label: const Text(
                                    'Connecté',
                                    style: TextStyle(
                                      color: FiestaaaPalette.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  backgroundColor: FiestaaaPalette.primary
                                      .withValues(alpha: 0.12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    avatar: const Icon(Icons.tag, size: 18),
                                    label: Text(profile.handle),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _updatingHandle
                                        ? null
                                        : () => _pickAndUploadAvatar(profile),
                                    icon: _updatingHandle
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.image),
                                    label: Text(_updatingHandle
                                        ? 'Envoi...'
                                        : 'Changer la photo'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _deletingAccount
                                        ? null
                                        : _confirmDeleteAccount,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    icon: _deletingAccount
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.delete_forever),
                                    label: const Text('Supprimer mon compte'),
                                  ),
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
