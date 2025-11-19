import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvitationStatusSection extends StatelessWidget {
  const InvitationStatusSection({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.invitations,
    required this.emptyLabel,
    this.onDelete,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<InvitationModel> invitations;
  final String emptyLabel;
  final void Function(InvitationModel invitation)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (invitations.isNotEmpty)
                  Chip(
                    label: Text('${invitations.length}'),
                    backgroundColor: accentColor.withOpacity(0.15),
                    side: BorderSide(color: accentColor.withOpacity(0.4)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (invitations.isEmpty)
              Text(
                emptyLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              )
            else
              ...invitations.map(_buildTile),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(InvitationModel invitation) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(invitation.email),
      subtitle: Text(
        'Envoyée le ${DateFormat.yMMMMd('fr_FR').format(invitation.dateInvi)}',
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              onPressed: () => onDelete!(invitation),
              icon: const Icon(Icons.delete),
              tooltip: 'Supprimer',
            ),
    );
  }
}
