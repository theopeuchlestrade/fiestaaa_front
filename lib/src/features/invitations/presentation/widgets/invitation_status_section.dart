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
    required this.ownerEmail,
    this.onDelete,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<InvitationModel> invitations;
  final String emptyLabel;
  final String ownerEmail;
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
    final isOwner =
        invitation.email.toLowerCase() == ownerEmail.toLowerCase();
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(invitation.email),
        if (isOwner) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Créateur de l’événement',
            child: Icon(
              Icons.emoji_events,
              color: Colors.amber.shade700,
              size: 18,
            ),
          ),
        ],
      ],
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: title,
      subtitle: Text(
        'Envoyée le ${DateFormat.yMMMMd('fr_FR').format(invitation.dateInvi)}',
      ),
      trailing: onDelete == null || isOwner
          ? null
          : IconButton(
              onPressed: () => onDelete!(invitation),
              icon: const Icon(Icons.delete),
              tooltip: 'Supprimer',
            ),
    );
  }
}
