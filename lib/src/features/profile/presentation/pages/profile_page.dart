import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/invitations/presentation/pages/my_invitations_page.dart';
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
  });

  final SessionData session;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ProfileApi();
  Future<ProfileInfo>? _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchProfile(widget.session.token);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FiestaaaBackground(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SafeArea(
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
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: widget.onLogout,
                                icon: const Icon(Icons.logout),
                                label: const Text('Se déconnecter'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MyInvitationsPage(
                                session: widget.session,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Mes invitations'),
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
  }
}
