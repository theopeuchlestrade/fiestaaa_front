import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
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
  });

  final SessionData session;
  final int eventId;
  final String ownerEmail;

  @override
  State<EventInvitationsPage> createState() => _EventInvitationsPageState();
}

class _EventInvitationsPageState extends State<EventInvitationsPage> {
  final _api = InvitationsApi();
  List<InvitationModel> _invitations = [];
  bool _loading = true;
  String? _error;

  final _emailController = TextEditingController();
  bool _submitting = false;
  Timer? _suggestionDebounce;
  List<InvitationSuggestionModel> _suggestions = [];
  bool _suggestionsLoading = false;

  bool get _isOwner =>
      widget.session.email.toLowerCase() == widget.ownerEmail.toLowerCase();

  @override
  void initState() {
    super.initState();
    if (_isOwner) {
      _emailController.addListener(_onEmailChanged);
    }
    _fetch();
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _api.dispose();
    _emailController.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _suggestionsLoading = false;
      });
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
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applySuggestion(String email) {
    _emailController
      ..text = email
      ..selection = TextSelection.collapsed(offset: email.length);
    setState(() {
      _suggestions = [];
    });
  }

  Future<void> _createInvitation() async {
    if (!_isOwner) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Email invalide', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _api.createInvitation(
        token: widget.session.token,
        eventId: widget.eventId,
        email: email,
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
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur lors de la création', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _submitting = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
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
            onDelete: _isOwner ? _deleteInvitation : null,
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
  final ValueChanged<String> onSuggestionSelected;

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
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
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
                  return ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: Text(suggestion.email),
                    subtitle: Text(
                      'Invité le ${formatter.format(suggestion.lastInvitedAt.toLocal())}',
                    ),
                    onTap: () => onSuggestionSelected(suggestion.email),
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
