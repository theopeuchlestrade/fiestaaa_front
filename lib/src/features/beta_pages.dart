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
  const BetaLinks({super.key, this.recovery = false});
  final bool recovery;
  @override
  Widget build(BuildContext context) => Wrap(
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
        ('support', 'Aide', 'Help'),
        ('delete-account', 'Suppression de compte', 'Account deletion'),
      ])
        TextButton(
          onPressed: () => context.push('/${item.$1}'),
          child: Text(betaText(context, item.$2, item.$3)),
        ),
    ],
  );
}

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.page});
  final String page;
  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final Future<Map<String, dynamic>> _pages = rootBundle
      .loadString('assets/legal/pages.json')
      .then((s) => jsonDecode(s) as Map<String, dynamic>);
  late final Future<PackageInfo> _version = PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fiestaaa • Bêta / Beta')),
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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (_done)
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
                )
              else ...[
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
  const SafetyPage({super.key, required this.token, this.eventId, this.api});
  final String token;
  final int? eventId;
  final BetaApi? api;
  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  late final _api = widget.api ?? BetaApi();
  final _handle = TextEditingController();
  final _comment = TextEditingController();
  String _reason = 'harassment';
  String? _message;
  bool _busy = false;
  late Future<dynamic> _blocks = _api.call('/me/blocks', token: widget.token);
  @override
  void dispose() {
    _api.close();
    _handle.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _act(String action, {String? publicId}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
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
          _message = betaText(
            context,
            'Demande enregistrée.',
            'Request recorded.',
          );
          _blocks = _api.call('/me/blocks', token: widget.token);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = betaText(
            context,
            'Impossible de traiter la demande. Vérifiez l’identifiant et votre connexion.',
            'Unable to process request. Check the handle and your connection.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        betaText(context, 'Sécurité et signalements', 'Safety and reports'),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.eventId == null) ...[
              Text(
                betaText(
                  context,
                  'Bloquer coupe les demandes d’amitié et invitations directes. Les événements communs restent accessibles ; vous pouvez les quitter ou les signaler.',
                  'Blocking stops friend requests and direct invitations. Shared events remain accessible; you can leave or report them.',
                ),
              ),
              TextField(
                controller: _handle,
                decoration: InputDecoration(
                  labelText: betaText(
                    context,
                    'Identifiant de la personne',
                    'User handle',
                  ),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _act('block'),
                child: Text(
                  betaText(
                    context,
                    'Bloquer les contacts directs',
                    'Block direct contact',
                  ),
                ),
              ),
            ] else
              Text(
                betaText(
                  context,
                  'Signaler cet événement',
                  'Report this event',
                ),
              ),
            DropdownButtonFormField<String>(
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
                    child: Text(betaText(context, r.$2, r.$3)),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _reason = v!),
            ),
            TextField(
              controller: _comment,
              maxLength: 1000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: betaText(
                  context,
                  'Détails du signalement',
                  'Report details',
                ),
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _act('report'),
              child: Text(
                betaText(context, 'Envoyer le signalement', 'Send report'),
              ),
            ),
            if (_message != null) Text(_message!),
            const SizedBox(height: 24),
            Text(
              betaText(context, 'Personnes bloquées', 'Blocked users'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder<dynamic>(
              future: _blocks,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () => setState(
                      () => _blocks = _api.call(
                        '/me/blocks',
                        token: widget.token,
                      ),
                    ),
                    child: Text(betaText(context, 'Réessayer', 'Retry')),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return Column(
                  children: [
                    for (final b in snapshot.data as List<dynamic>)
                      ListTile(
                        title: Text(b['handle'] as String),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _act(
                                  'unblock',
                                  publicId: b['public_id'] as String,
                                ),
                          child: Text(
                            betaText(context, 'Débloquer', 'Unblock'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const BetaLinks(),
          ],
        ),
      ),
    ),
  );
}
