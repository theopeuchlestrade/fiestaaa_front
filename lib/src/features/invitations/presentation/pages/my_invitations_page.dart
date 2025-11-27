import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyInvitationsPage extends StatefulWidget {
  const MyInvitationsPage({
    super.key,
    required this.session,
    this.onOpenEvent,
  });

  final SessionData session;
  final void Function(int eventId)? onOpenEvent;

  @override
  State<MyInvitationsPage> createState() => _MyInvitationsPageState();
}

class _MyInvitationsPageState extends State<MyInvitationsPage> {
  final _api = InvitationsApi();
  List<InvitationModel> _invitations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchMyInvitations(widget.session.token);
      if (!mounted) return;
      setState(() {
        _invitations = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger vos invitations.');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(InvitationModel invitation, String status) async {
    try {
      await _api.respondInvitation(
        token: widget.session.token,
        eventId: invitation.eventId,
        status: status,
      );
      if (!mounted) return;
      _showSnack(
        status == 'Accepted' ? 'Invitation acceptée' : 'Invitation refusée',
      );
      await _fetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Action impossible', isError: true);
    }
  }

  Future<void> _confirmLeave(InvitationModel invitation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter cet événement ?'),
        content: Text(
          'Vous êtes actuellement inscrit. Quitter l’événement retirera vos engagements pour ${invitation.eventName ?? 'cet évènement'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _respond(invitation, 'Declined');
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
        title: const Text('Mes invitations'),
      ),
      body: FiestaaaBackground(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: RefreshIndicator(
          onRefresh: _fetch,
          displacement: 28,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            children: [
              if (_loading)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Column(
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                )
              else if (_invitations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Aucune invitation en attente.'),
                  ),
                )
              else
                ..._invitations.map(
                  (inv) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onOpenEvent == null
                          ? null
                          : () => widget.onOpenEvent!(inv.eventId),
                      splashColor: FiestaaaPalette.primary.withOpacity(0.12),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                              inv.eventName ?? 'Évènement #${inv.eventId}'),
                          subtitle: Text(
                            'Reçu le ${DateFormat.yMMMMd('fr_FR').format(inv.dateInvi)}',
                          ),
                          leading: Icon(
                            Icons.mail_outline,
                            color: inv.status == 'Accepted'
                                ? Colors.green
                                : inv.status == 'Declined'
                                    ? Colors.redAccent
                                    : FiestaaaPalette.primary,
                          ),
                          trailing: inv.status == 'Waiting'
                              ? Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          _respond(inv, 'Declined'),
                                      child: const Text('Refuser'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _respond(inv, 'Accepted'),
                                      child: const Text('Accepter'),
                                    ),
                                  ],
                                )
                              : inv.status == 'Accepted'
                                  ? TextButton.icon(
                                      onPressed: () => _confirmLeave(inv),
                                      icon: const Icon(Icons.logout),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                      ),
                                      label: const Text('Quitter'),
                                    )
                                  : Chip(
                                      label: Text(
                                        inv.status,
                                        style: TextStyle(
                                          color: inv.status == 'Accepted'
                                              ? Colors.green.shade800
                                              : inv.status == 'Declined'
                                                  ? Colors.grey.shade800
                                                  : Colors.orange.shade800,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      backgroundColor: inv.status == 'Accepted'
                                          ? Colors.green.shade100
                                          : inv.status == 'Declined'
                                              ? Colors.grey.shade200
                                              : Colors.orange.shade100,
                                    ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
