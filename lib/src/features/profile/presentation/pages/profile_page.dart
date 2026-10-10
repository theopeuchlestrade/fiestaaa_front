import 'package:fiestaaa_front/src/core/platform_network_image.dart';
import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:fiestaaa_front/src/features/beta_api.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/data/apple_sign_in.dart';
import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/avatar_file_picker.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_error_localizer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onSessionUpdated,
    this.localeService,
    this.themeService,
    this.api,
  });

  final ProfileApi? api;
  final SessionData session;
  final VoidCallback onLogout;
  final Future<void> Function(SessionData session)? onSessionUpdated;
  final LocaleService? localeService;
  final ThemeService? themeService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const double _maxAvatarSizeMb = 8;

  late final _api = widget.api ?? ProfileApi();
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

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.token != oldWidget.session.token ||
        widget.session.publicId != oldWidget.session.publicId ||
        widget.session.email != oldWidget.session.email) {
      _future = _api.fetchProfile(widget.session.token);
    }
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
        _handleStatus = localizedApiError(l10n, e, fallback: l10n.checkFailed);
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
      final message = localizedApiError(l10n, e, fallback: l10n.updateFailed);
      _showSnack(message, isError: true);
      setState(() {
        _handleAvailable = false;
        _handleStatus = message;
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
      try {
        await _api.deleteAccount(token: widget.session.token);
      } on ApiException catch (error) {
        if (error.code != 'apple_reauthentication_required') rethrow;
        final credential = await requestAppleCredential();
        final beta = BetaApi();
        try {
          await beta.call(
            '/me/apple-reauthorize',
            method: 'POST',
            token: widget.session.token,
            body: {
              'idToken': credential.identityToken,
              'authorizationCode': credential.authorizationCode,
              if (appleUsesAndroidCallback) 'android': true,
            },
          );
        } finally {
          beta.close();
        }
        await _api.deleteAccount(token: widget.session.token);
      }
      if (!mounted) return;
      _showSnack(l10n.accountDeleted);
      widget.onLogout();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(
        localizedApiError(l10n, e, fallback: l10n.deletionFailed),
        isError: true,
      );
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

  String _languageLabel(Locale? locale, S l10n) {
    if (locale == null) {
      return l10n.themeSystem;
    }
    return widget.localeService?.getLanguageName(locale.languageCode) ??
        locale.languageCode;
  }

  Future<void> _showLanguageDialog() async {
    final l10n = S.of(context);
    final currentLocale = widget.localeService?.locale;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.changeLanguage),
        children: [
          ListTile(
            leading: currentLocale == null
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.fiestaaaSuccess,
                  )
                : const SizedBox(width: 24),
            title: Text(l10n.themeSystem),
            onTap: () => Navigator.of(ctx).pop('system'),
          ),
          for (final locale in LocaleService.supportedLocales)
            ListTile(
              leading: currentLocale?.languageCode == locale.languageCode
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

    if (selected == null || widget.localeService == null) {
      return;
    }

    if (selected == 'system') {
      await widget.localeService!.clearLocale();
      return;
    }

    await widget.localeService!.setLocale(Locale(selected));
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

    late final AvatarFile file;
    try {
      final selected = await pickAvatarFile();
      if (selected == null) return;
      file = selected;
      final sizeMb = file.bytes.length / (1024 * 1024);
      if (sizeMb > _maxAvatarSizeMb) {
        _showSnack(l10n.imageTooLarge, isError: true);
        return;
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.uploadFailed, isError: true);
      return;
    }

    setState(() => _updatingHandle = true);
    try {
      final updated = await _api.uploadAvatar(
        token: widget.session.token,
        filename: file.name.isNotEmpty ? file.name : 'avatar.jpg',
        bytes: file.bytes,
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
      _showSnack(
        localizedApiError(l10n, e, fallback: l10n.uploadFailed),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.uploadFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _updatingHandle = false);
      }
    }
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    return FiestaaaPageLayout(
      maxWidth: 760,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FiestaaaPageHeader(title: l.myProfile),
            FutureBuilder<ProfileInfo>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Text(l.profileLoadFailed),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _future = _api.fetchProfile(
                              widget.session.token,
                            ),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: Text(l.retry),
                        ),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = snapshot.data!;
                if (_handleController.text.isEmpty) {
                  _handleController.text = profile.handle;
                }
                return _section(betaText(context, 'Compte', 'Account'), [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: profile.avatarUrl == null
                            ? null
                            : platformNetworkImage(profile.avatarUrl!),
                        child: profile.avatarUrl == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(profile.email)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _updatingHandle
                          ? null
                          : () => _pickAndUploadAvatar(profile),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _updatingHandle ? l.uploading : l.changePhoto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _handleController,
                    enabled: !_updatingHandle,
                    decoration: InputDecoration(
                      labelText: l.identifierExample,
                      helperText: l.identifierHelperText,
                      prefixIcon: const Icon(Icons.alternate_email),
                    ),
                  ),
                  if (_handleStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _handleStatus!,
                        style: TextStyle(
                          color: _handleAvailable == false
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).fiestaaaMutedText,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _checkingHandle
                            ? null
                            : _checkHandleAvailability,
                        icon: const Icon(Icons.search),
                        label: Text(l.check),
                      ),
                      FilledButton.icon(
                        onPressed: _updatingHandle
                            ? null
                            : () => _updateHandle(profile),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_updatingHandle ? l.updating : l.update),
                      ),
                      TextButton.icon(
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout),
                        label: Text(l.logout),
                      ),
                    ],
                  ),
                ]);
              },
            ),
            const SizedBox(height: 12),
            _section(betaText(context, 'Préférences', 'Preferences'), [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.themeService != null)
                    OutlinedButton.icon(
                      onPressed: _showThemeDialog,
                      icon: const Icon(Icons.brightness_6_outlined),
                      label: Text(
                        '${l.changeTheme} · ${_themeLabel(widget.themeService!.mode, l)}',
                      ),
                    ),
                  if (widget.localeService != null)
                    OutlinedButton.icon(
                      onPressed: _showLanguageDialog,
                      icon: const Icon(Icons.translate),
                      label: Text(
                        '${l.changeLanguage} · ${_languageLabel(widget.localeService!.locale, l)}',
                      ),
                    ),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _section(betaText(context, 'Sécurité', 'Safety'), [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined),
                title: Text(
                  betaText(
                    context,
                    'Blocages et signalements',
                    'Blocks and reports',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/safety'),
              ),
            ]),
            const SizedBox(height: 12),
            _section(betaText(context, 'Aide', 'Help'), [const BetaLinks()]),
            const SizedBox(height: 24),
            _section(l.deleteMyAccount, [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _deletingAccount ? null : _confirmDeleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(l.deleteMyAccount),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
