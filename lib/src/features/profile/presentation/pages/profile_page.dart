import 'package:file_selector/file_selector.dart';
import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onSessionUpdated,
    this.localeService,
    this.themeService,
  });

  final SessionData session;
  final VoidCallback onLogout;
  final Future<void> Function(SessionData session)? onSessionUpdated;
  final LocaleService? localeService;
  final ThemeService? themeService;

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
    final l10n = S.of(context);
    final handle = _handleController.text.trim();
    if (handle.isEmpty) {
      setState(() {
        _handleStatus = l10n.enterIdentifierToCheck;
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
        _handleStatus = available
            ? l10n.identifierAvailable
            : l10n.identifierTaken;
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
        _handleStatus = l10n.checkFailed;
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
    final l10n = S.of(context);
    final handle = _handleController.text.trim();
    if (handle.isEmpty) {
      _showSnack(l10n.pleaseEnterIdentifier, isError: true);
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
        _handleStatus = l10n.identifierUpdated;
      });
      if (widget.onSessionUpdated != null) {
        await widget.onSessionUpdated!(
          widget.session.copyWith(handle: updated.handle),
        );
      }
      _showSnack(l10n.identifierUpdated);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
      setState(() {
        _handleAvailable = false;
        _handleStatus = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.updateFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingHandle = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.fiestaaaDanger,
            ),
            child: Text(l10n.delete),
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
      _showSnack(l10n.accountDeleted);
      widget.onLogout();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.deletionFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
      }
    }
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

  Future<void> _showLanguageDialog() async {
    final l10n = S.of(context);
    final currentLocale =
        widget.localeService?.locale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.changeLanguage),
        children: [
          for (final locale in LocaleService.supportedLocales)
            ListTile(
              leading: currentLocale == locale.languageCode
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.fiestaaaSuccess,
                    )
                  : const SizedBox(width: 24),
              title: Text(
                widget.localeService?.getLanguageName(locale.languageCode) ??
                    locale.languageCode,
              ),
              onTap: () => Navigator.of(ctx).pop(locale.languageCode),
            ),
        ],
      ),
    );

    if (selected != null && widget.localeService != null) {
      await widget.localeService!.setLocale(Locale(selected));
    }
  }

  String _themeLabel(ThemeMode mode, S l10n) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
    }
  }

  Future<void> _showThemeDialog() async {
    final themeService = widget.themeService;
    if (themeService == null) return;
    final l10n = S.of(context);
    final currentTheme = themeService.mode;

    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.changeTheme),
        children: [
          for (final mode in [
            ThemeMode.system,
            ThemeMode.light,
            ThemeMode.dark,
          ])
            ListTile(
              leading: currentTheme == mode
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.fiestaaaSuccess,
                    )
                  : const SizedBox(width: 24),
              title: Text(_themeLabel(mode, l10n)),
              onTap: () => Navigator.of(ctx).pop(mode),
            ),
        ],
      ),
    );

    if (selected != null) {
      await themeService.setMode(selected);
    }
  }

  Future<void> _pickAndUploadAvatar(ProfileInfo profile) async {
    final l10n = S.of(context);
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final sizeMb = bytes.length / (1024 * 1024);
    if (sizeMb > 1.5) {
      _showSnack(l10n.imageTooLarge, isError: true);
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
          widget.session.copyWith(handle: updated.handle),
        );
      }
      _showSnack(l10n.photoUpdated);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.uploadFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingHandle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return FiestaaaPageLayout(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FiestaaaPageHeader(
              title: l10n.myProfile,
              subtitle: l10n.manageAccountAndInvitations,
            ),
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
                      Text(l10n.profileLoadFailed),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _future = _api.fetchProfile(widget.session.token);
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ],
                  );
                }

                final profile = snapshot.data;
                if (profile == null) {
                  return Text(l10n.profileNotFound);
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
                                backgroundColor: FiestaaaPalette.primary
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                l10n.tokenValidUntil(
                                  DateFormat.yMMMMd(
                                    locale,
                                  ).format(profile.expiration),
                                  DateFormat.Hm().format(profile.expiration),
                                ),
                              ),
                              trailing: Chip(
                                label: Text(
                                  l10n.connected,
                                  style: const TextStyle(
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
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.image),
                                  label: Text(
                                    _updatingHandle
                                        ? l10n.uploading
                                        : l10n.changePhoto,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _deletingAccount
                                      ? null
                                      : _confirmDeleteAccount,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.fiestaaaDanger,
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.fiestaaaDanger,
                                    ),
                                  ),
                                  icon: _deletingAccount
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_forever),
                                  label: Text(l10n.deleteMyAccount),
                                ),
                                OutlinedButton.icon(
                                  onPressed: widget.onLogout,
                                  icon: const Icon(Icons.logout),
                                  label: Text(l10n.logout),
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
                                Icon(
                                  Icons.edit_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.updateIdentifier,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                if (_checkingHandle || _updatingHandle)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _handleController,
                              enabled: !_updatingHandle,
                              decoration: InputDecoration(
                                labelText: l10n.identifierExample,
                                helperText: l10n.identifierHelperText,
                                prefixIcon: const Icon(Icons.alternate_email),
                                suffixIcon: _handleAvailable == true
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.fiestaaaSuccess,
                                      )
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
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.fiestaaaDanger
                                        : Theme.of(
                                            context,
                                          ).colorScheme.fiestaaaSuccess,
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
                                  label: Text(l10n.check),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _updatingHandle
                                      ? null
                                      : () => _updateHandle(profile),
                                  icon: const Icon(Icons.save_outlined),
                                  label: Text(
                                    _updatingHandle
                                        ? l10n.updating
                                        : l10n.update,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.themeService != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.dark_mode,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.changeTheme,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _showThemeDialog,
                                icon: const Icon(Icons.brightness_6_outlined),
                                label: Text(
                                  _themeLabel(
                                    widget.themeService?.mode ??
                                        ThemeMode.system,
                                    l10n,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (widget.localeService != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.language,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.changeLanguage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _showLanguageDialog,
                                icon: const Icon(Icons.translate),
                                label: Text(
                                  widget.localeService?.getLanguageName(
                                        widget
                                                .localeService
                                                ?.locale
                                                ?.languageCode ??
                                            locale,
                                      ) ??
                                      l10n.french,
                                ),
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
    );
  }
}
