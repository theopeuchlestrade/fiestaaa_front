import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventInvitationsPage extends StatefulWidget {
  const EventInvitationsPage({
    super.key,
    required this.session,
    required this.eventId,
  });

  final SessionData session;
  final int eventId;

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

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _api.dispose();
    _emailController.dispose();
    super.dispose();
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

  Future<void> _createInvitation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Email invalide', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.createInvitation(
        token: widget.session.token,
        eventId: widget.eventId,
        email: email,
      );
      if (!mounted) return;
      _emailController.clear();
      await _fetch();
      _showSnack('Invitation créée');
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
            _InviteForm(
              emailController: _emailController,
              onSubmit: _submitting ? null : _createInvitation,
              submitting: _submitting,
            ),
            const SizedBox(height: 24),
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
              ..._invitations.map(
                (inv) => Card(
                  child: ListTile(
                    title: Text(inv.email),
                    subtitle: Text(
                      'Statut : ${inv.status}\nEnvoyée le ${DateFormat.yMMMMd('fr_FR').format(inv.dateInvi)}',
                    ),
                    trailing: IconButton(
                      onPressed: () => _deleteInvitation(inv),
                      icon: const Icon(Icons.delete),
                      tooltip: 'Supprimer',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
