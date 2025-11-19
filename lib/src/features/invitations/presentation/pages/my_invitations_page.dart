import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyInvitationsPage extends StatefulWidget {
  const MyInvitationsPage({super.key, required this.session});

  final SessionData session;

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
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Column(
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetch,
                    child: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_invitations.isEmpty)
              const Center(
                child: Text('Aucune invitation en attente.'),
              )
            else
              ..._invitations.map(
                (inv) => Card(
                  child: ListTile(
                    title: Text(inv.eventName ?? 'Évènement #${inv.eventId}'),
                    subtitle: Text(
                      'Statut : ${inv.status}\nReçu le ${DateFormat.yMMMMd('fr_FR').format(inv.dateInvi)}',
                    ),
                    trailing: inv.status == 'Waiting'
                        ? Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _respond(inv, 'Declined'),
                                child: const Text('Refuser'),
                              ),
                              ElevatedButton(
                                onPressed: () => _respond(inv, 'Accepted'),
                                child: const Text('Accepter'),
                              ),
                            ],
                          )
                        : Text(
                            inv.status,
                            style: TextStyle(
                              color: inv.status == 'Accepted'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
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
