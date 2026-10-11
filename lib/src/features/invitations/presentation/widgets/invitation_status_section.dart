import 'package:fiestaaa_front/src/core/platform_network_image.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
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
    this.showHeading = true,
    this.onDelete,
    this.trailingBuilder,
  });

  final bool showHeading;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<InvitationModel> invitations;
  final String emptyLabel;
  final String ownerEmail;
  final void Function(InvitationModel invitation)? onDelete;
  final Widget? Function(InvitationModel invitation)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeading)
              Text(
                invitations.isEmpty ? title : '$title · ${invitations.length}',
                style: theme.textTheme.titleSmall,
              ),
            if (showHeading) const SizedBox(height: 12),
            if (invitations.isEmpty)
              Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.fiestaaaMutedText,
                ),
              )
            else
              ...invitations.map(
                (invitation) => _buildTile(context, invitation),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, InvitationModel invitation) {
    final isOwner = invitation.email.toLowerCase() == ownerEmail.toLowerCase();
    final handle = invitation.handle?.isNotEmpty == true
        ? invitation.handle!
        : S.of(context).accountToCreate;
    final display = invitation.handle?.isNotEmpty == true ? '@$handle' : handle;
    final title = Text(display, style: Theme.of(context).textTheme.bodyLarge);
    Widget? trailing;
    if (trailingBuilder != null) {
      trailing = trailingBuilder!(invitation);
    } else if (onDelete != null && !isOwner) {
      trailing = IconButton(
        onPressed: () => onDelete!(invitation),
        icon: const Icon(Icons.delete),
        tooltip: S.of(context).delete,
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _AvatarCircle(
        url: invitation.avatarUrl,
        fallbackText: invitation.handle ?? invitation.email,
      ),
      title: title,
      subtitle: isOwner
          ? Text(S.of(context).eventCreator)
          : Text(
              S
                  .of(context)
                  .sentOn(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(invitation.dateInvi),
                  ),
            ),
      trailing: trailing,
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({this.url, this.fallbackText});

  final String? url;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = (fallbackText ?? '')
        .trim()
        .characters
        .take(1)
        .toString()
        .toUpperCase();
    Widget placeholder() => CircleAvatar(
      backgroundColor: theme.fiestaaaAvatarSurface,
      foregroundColor: theme.colorScheme.onSurface,
      child: Text(
        letter.isNotEmpty ? letter : '?',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (url == null || url!.isEmpty) return placeholder();
    return CircleAvatar(
      backgroundColor: theme.fiestaaaAvatarSurface,
      backgroundImage: platformNetworkImage(url!),
      onBackgroundImageError: (error, stackTrace) {},
      child: null,
    );
  }
}
