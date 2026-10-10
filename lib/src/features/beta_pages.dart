import '../theme/fiestaaa_theme.dart';
import '../core/presentation/widgets/route_back_button.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'beta_api.dart';
import '../core/api_response.dart';

String betaText(BuildContext context, String fr, String en) =>
    Localizations.localeOf(context).languageCode == 'fr' ? fr : en;

class BetaLinks extends StatelessWidget {
  const BetaLinks({super.key, this.recovery = false, this.list = false});
  final bool recovery;
  final bool list;
  @override
  Widget build(BuildContext context) {
    if (list) {
      return Column(
        children: [
          for (final item in [
            ('support', 'Assistance', 'Support', Icons.help_outline),
            (
              'privacy',
              'Confidentialité',
              'Privacy',
              Icons.privacy_tip_outlined,
            ),
            ('terms', 'Conditions', 'Terms', Icons.description_outlined),
            (
              'delete-account',
              'Suppression de compte',
              'Account deletion',
              Icons.person_remove_outlined,
            ),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.$4),
              title: Text(betaText(context, item.$2, item.$3)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/${item.$1}'),
            ),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (recovery)
          TextButton(
            onPressed: () => context.push('/reset-password'),
            child: Text(
              betaText(context, 'Mot de passe oublié ?', 'Forgot password?'),
            ),
          ),
        for (final item in [
          ('privacy', 'Confidentialité', 'Privacy'),
          ('terms', 'Conditions', 'Terms'),
          ('support', 'Assistance', 'Support'),
          ('delete-account', 'Suppression de compte', 'Account deletion'),
        ])
          TextButton(
            onPressed: () => context.push('/${item.$1}'),
            child: Text(betaText(context, item.$2, item.$3)),
          ),
      ],
    );
  }
}

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.page, this.pages});
  final String page;
  final Future<Map<String, dynamic>>? pages;
  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final Future<Map<String, dynamic>> _pages =
      widget.pages ??
      rootBundle
          .loadString('assets/legal/pages.json')
          .then((s) => jsonDecode(s) as Map<String, dynamic>);
  late final Future<PackageInfo> _version = PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const RouteBackButton(fallback: '/events')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _pages,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('feedback@fiestaaa.app'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final locale = Localizations.localeOf(context).languageCode == 'fr'
            ? 'fr'
            : 'en';
        final paragraphs =
            (snapshot.data![widget.page] as Map<String, dynamic>)[locale]
                as List<dynamic>;
        return FiestaaaBackground(
          child: FiestaaaPageLayout(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  paragraphs.first as String,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                for (final paragraph in paragraphs.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SelectableText(paragraph as String),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: 'feedback@fiestaaa.app',
                      queryParameters: {
                        'subject': widget.page == 'delete-account'
                            ? 'Suppression de compte Fiestaaa'
                            : 'Fiestaaa — Bêta',
                      },
                    ),
                  ),
                  child: const Text('feedback@fiestaaa.app'),
                ),
                if (widget.page == 'support')
                  FutureBuilder<PackageInfo>(
                    future: _version,
                    builder: (context, version) => Text(
                      version.hasData
                          ? 'Fiestaaa ${version.data!.version} (${version.data!.buildNumber}) • Bêta / Beta'
                          : 'Fiestaaa • Bêta / Beta',
                    ),
                  ),
                const BetaLinks(),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, this.token, this.api});
  final String? token;
  final BetaApi? api;
  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final _api = widget.api ?? BetaApi();
  bool _busy = false;
  bool _done = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final reset = widget.token != null;
    if (reset && _password.text != _confirmation.text) {
      setState(
        () => _error = betaText(
          context,
          'Les mots de passe diffèrent.',
          'Passwords do not match.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.call(
        '/auth/password-reset/${reset ? 'confirm' : 'request'}',
        method: 'POST',
        body: reset
            ? {'token': widget.token, 'password': _password.text}
            : {'email': _email.text.trim()},
      );
      if (mounted) setState(() => _done = true);
      _password.clear();
      _confirmation.clear();
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = betaText(
            context,
            e.statusCode == 429
                ? 'Trop de demandes. Réessayez plus tard.'
                : 'La demande a échoué. Vérifiez le mot de passe ou demandez un nouveau lien.',
            e.statusCode == 429
                ? 'Too many requests. Try later.'
                : 'Request failed. Check the password or request a new link.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = betaText(
            context,
            'Connexion indisponible. Réessayez.',
            'Connection unavailable. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reset = widget.token != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          betaText(context, 'Récupérer mon compte', 'Recover my account'),
        ),
      ),
      body: FiestaaaBackground(
        child: FiestaaaPageLayout(
          maxWidth: 760,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (_done) ...[
                Text(
                  betaText(
                    context,
                    reset
                        ? 'Mot de passe modifié. Reconnectez-vous sur vos appareils.'
                        : 'Si ce compte utilise un mot de passe, un email vous sera envoyé. Pour Apple ou Google, utilisez votre fournisseur de connexion.',
                    reset
                        ? 'Password changed. Sign in again on your devices.'
                        : 'If this account uses a password, an email will be sent. For Apple or Google, use your sign-in provider.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/auth'),
                  child: Text(
                    betaText(
                      context,
                      'Revenir à la connexion',
                      'Return to sign in',
                    ),
                  ),
                ),
              ] else ...[
                if (!reset)
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                if (reset) ...[
                  Text(
                    betaText(
                      context,
                      'Au moins 12 caractères, avec majuscule, minuscule, chiffre et symbole.',
                      'At least 12 characters including uppercase, lowercase, digit and symbol.',
                    ),
                  ),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: betaText(
                        context,
                        'Nouveau mot de passe',
                        'New password',
                      ),
                    ),
                  ),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: betaText(
                        context,
                        'Confirmer le mot de passe',
                        'Confirm password',
                      ),
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_error!),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    betaText(
                      context,
                      _busy ? 'En cours…' : 'Continuer',
                      _busy ? 'Working…' : 'Continue',
                    ),
                  ),
                ),
              ],
              TextButton(
                onPressed: () => context.go('/auth'),
                child: Text(
                  betaText(context, 'Retour à la connexion', 'Back to sign in'),
                ),
              ),
              const BetaLinks(),
            ],
          ),
        ),
      ),
    );
  }
}

class SafetyPage extends StatefulWidget {
  const SafetyPage({
    super.key,
    required this.token,
    this.eventId,
    this.api,
    this.initialHandle,
  });
  final String token;
  final String? initialHandle;
  final int? eventId;
  final BetaApi? api;
  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  late final _api = widget.api ?? BetaApi();
  late final _handle = TextEditingController(text: widget.initialHandle);
  final _comment = TextEditingController();
  final _scroll = ScrollController();
  String _reason = 'harassment';
  String? _message;
  bool _busy = false;
  late Future<dynamic> _blocks = _api.call('/me/blocks', token: widget.token);
  @override
  void dispose() {
    _api.close();
    _handle.dispose();
    _comment.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _act(String action, {String? publicId}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      var id = publicId;
      if (action != 'unblock' && widget.eventId == null) {
        final target =
            await _api.call(
                  '/safety/user?handle=${Uri.encodeQueryComponent(_handle.text.trim())}',
                  token: widget.token,
                )
                as Map<String, dynamic>;
        id = target['public_id'] as String;
      }
      if (action == 'report') {
        await _api.call(
          '/reports',
          method: 'POST',
          token: widget.token,
          body: {
            if (widget.eventId != null)
              'event_id': widget.eventId
            else
              'public_id': id,
            'reason': _reason,
            'comment': _comment.text,
          },
        );
      } else if (action == 'unblock') {
        await _api.call(
          '/me/blocks/$id',
          method: 'DELETE',
          token: widget.token,
        );
      } else {
        await _api.call(
          '/me/blocks',
          method: 'POST',
          token: widget.token,
          body: {'public_id': id},
        );
      }
      if (mounted) {
        setState(() {
          _message = action == 'report'
              ? _text(
                  'Signalement envoyé. Merci de nous avoir prévenus.',
                  'Report sent. Thank you for letting us know.',
                )
              : action == 'block'
              ? _text(
                  'La personne a été bloquée.',
                  'The person has been blocked.',
                )
              : _text(
                  'La personne a été débloquée.',
                  'The person has been unblocked.',
                );
          if (widget.eventId == null) _action = null;
          if (action == 'report') _comment.clear();
          _blocks = _api.call('/me/blocks', token: widget.token);
        });
        _showFeedback();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = _text(
            'Impossible de traiter la demande. Vérifiez l’identifiant et votre connexion.',
            'Unable to process request. Check the handle and your connection.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _showFeedback();
      }
    }
  }

  void _showFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? _action;
  bool _failed = false;

  String _text(String fr, String en) => betaText(context, fr, en);

  void _selectAction(String action) => setState(() {
    _action = action;
    _message = null;
    _failed = false;
  });

  Future<void> _submit() async {
    if (widget.eventId == null && _handle.text.trim().isEmpty) {
      setState(() {
        _failed = true;
        _message = _text(
          'Saisissez l’identifiant de la personne.',
          'Enter the user handle.',
        );
      });
      return;
    }
    final action = widget.eventId != null ? 'report' : _action!;
    if (action == 'block') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _text(
              'Bloquer @${_handle.text.trim()} ?',
              'Block @${_handle.text.trim()}?',
            ),
          ),
          content: Text(
            _text(
              'L’amitié et les demandes en attente seront retirées. Les demandes d’amitié et invitations directes seront bloquées dans les deux sens. Les événements communs et les contributions restent accessibles.',
              'The friendship and pending requests will be removed. Friend requests and direct invitations will be blocked both ways. Shared events and contributions remain accessible.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_text('Annuler', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_text('Bloquer', 'Block')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    await _act(action);
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
  }) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _busy ? null : () => _selectAction(action),
    ),
  );

  Widget _blockedUsers() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text('Personnes bloquées', 'Blocked users'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FutureBuilder<dynamic>(
            future: _blocks,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        'La liste n’a pas pu être chargée.',
                        'The list could not be loaded.',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _blocks = _api.call(
                          '/me/blocks',
                          token: widget.token,
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(_text('Réessayer', 'Retry')),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final blocks = snapshot.data as List<dynamic>;
              if (blocks.isEmpty) {
                return Text(
                  _text(
                    'Vous n’avez bloqué personne.',
                    'You have not blocked anyone.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final b in blocks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('@${b['handle']}'),
                      trailing: TextButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                'unblock',
                                publicId: b['public_id'] as String,
                              ),
                        child: Text(_text('Débloquer', 'Unblock')),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reporting = widget.eventId != null || _action == 'report';
    final editing = widget.eventId != null || _action != null;
    final title = editing
        ? (reporting
              ? _text('Signaler un problème', 'Report a problem')
              : _text('Bloquer une personne', 'Block someone'))
        : _text('Sécurité et signalements', 'Safety and reports');
    return Scaffold(
      appBar: AppBar(
        leading: _action != null && widget.eventId == null
            ? BackButton(
                onPressed: _busy
                    ? () {}
                    : () => setState(() {
                        _action = null;
                        _message = null;
                      }),
              )
            : const RouteBackButton(fallback: '/profile'),
        title: Text(title),
      ),
      body: FiestaaaBackground(
        child: FiestaaaPageLayout(
          maxWidth: 760,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(20),
            children: [
              if (_message != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Card(
                    color: _failed
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _message!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _failed
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!editing) ...[
                Text(
                  _text(
                    'Choisissez ce dont vous avez besoin.',
                    'Choose how we can help.',
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _actionCard(
                  icon: Icons.person_off_outlined,
                  title: _text('Bloquer une personne', 'Block someone'),
                  subtitle: _text(
                    'Arrêter les demandes et invitations directes.',
                    'Stop friend requests and direct invitations.',
                  ),
                  action: 'block',
                ),
                const SizedBox(height: 12),
                _actionCard(
                  icon: Icons.flag_outlined,
                  title: _text('Signaler un problème', 'Report a problem'),
                  subtitle: _text(
                    'Alerter l’équipe sur une personne ou un contenu.',
                    'Notify the team about a person or content.',
                  ),
                  action: 'report',
                ),
                const SizedBox(height: 24),
                _blockedUsers(),
              ] else ...[
                Text(
                  reporting
                      ? _text(
                          'Votre signalement sera examiné par l’équipe. Il ne bloque pas automatiquement la personne.',
                          'The team will review your report. Reporting does not automatically block the person.',
                        )
                      : _text(
                          'Les contacts directs seront coupés dans les deux sens. Les événements communs restent accessibles ; vous pouvez les quitter ou les signaler.',
                          'Direct contact will be blocked both ways. Shared events remain accessible; you can leave or report them.',
                        ),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.eventId == null) ...[
                          TextField(
                            controller: _handle,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: _text(
                                'Identifiant de la personne',
                                'User handle',
                              ),
                              hintText: _text(
                                'Exemple : alex',
                                'Example: alex',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          Text(
                            _text('Événement concerné', 'Reported event'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _text(
                              'L’événement depuis lequel vous avez ouvert cette page.',
                              'The event from which you opened this page.',
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (reporting) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            itemHeight: null,
                            decoration: InputDecoration(
                              labelText: _text('Motif', 'Reason'),
                            ),
                            initialValue: _reason,
                            items: [
                              for (final r in [
                                ('harassment', 'Harcèlement', 'Harassment'),
                                (
                                  'inappropriate',
                                  'Contenu inapproprié',
                                  'Inappropriate content',
                                ),
                                ('spam', 'Spam', 'Spam'),
                                ('other', 'Autre', 'Other'),
                              ])
                                DropdownMenuItem(
                                  value: r.$1,
                                  child: Text(_text(r.$2, r.$3)),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _reason = v!),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _comment,
                            enabled: !_busy,
                            maxLength: 1000,
                            minLines: 3,
                            maxLines: 6,
                            decoration: InputDecoration(
                              labelText: _text(
                                'Détails (facultatif)',
                                'Details (optional)',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  reporting
                                      ? _text(
                                          'Envoyer le signalement',
                                          'Send report',
                                        )
                                      : _text('Continuer', 'Continue'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => context.push('/support'),
                icon: const Icon(Icons.help_outline),
                label: Text(_text('Contacter l’assistance', 'Contact support')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
