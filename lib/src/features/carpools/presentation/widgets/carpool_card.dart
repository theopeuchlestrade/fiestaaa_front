import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:fiestaaa_front/src/core/platform_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:url_launcher/url_launcher.dart';

class CarpoolCard extends StatelessWidget {
  final CarpoolModel carpool;
  final bool isDriver;
  final bool isPassenger;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? unavailableReason;
  final bool isJoining;
  final bool isLeaving;

  const CarpoolCard({
    super.key,
    required this.carpool,
    required this.isDriver,
    required this.isPassenger,
    this.onJoin,
    this.onLeave,
    this.onEdit,
    this.onDelete,
    this.unavailableReason,
    this.isJoining = false,
    this.isLeaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = S.of(context);
    final notes = carpool.notes?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _formatDepartureTime(context, carpool.departAt),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (isDriver && onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: betaText(
                      context,
                      'Actions du trajet',
                      'Ride actions',
                    ),
                    onSelected: (_) => onDelete!(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'delete', child: Text(l.delete)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              iconColor: theme.colorScheme.primary,
              text: carpool.origin,
              onTap: () => _openMap(context, carpool),
              actionIcon: Icons.map_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _DriverAvatar(
                  handle: carpool.driverHandle,
                  avatarUrl: carpool.driverAvatarUrl,
                  isCurrentUser: isDriver,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carpool.driverHandle ?? l.unknownDriver,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (isDriver || isPassenger)
                        Text(
                          isDriver ? l.youAreDriver : l.youArePassenger,
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              carpool.isFull
                  ? l.carpoolFull
                  : '${carpool.seatsAvailable} ${l.seatsAvailable(carpool.seatsAvailable)} ${betaText(context, carpool.seatsAvailable == 1 ? 'disponible' : 'disponibles', 'available')}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((notes?.isNotEmpty ?? false) ||
                carpool.passengers.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  betaText(context, 'Détails du trajet', 'Ride details'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (notes?.isNotEmpty ?? false) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        notes!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (carpool.passengers.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.passengersCount(carpool.passengers.length),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final passenger in carpool.passengers)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _DriverAvatar(
                          handle: passenger.handle,
                          avatarUrl: passenger.avatarUrl,
                          isCurrentUser: false,
                        ),
                        title: Text(passenger.handle ?? l.anonymous),
                      ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildActions(context, l),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, S l) {
    if (isDriver) {
      return onEdit == null
          ? const SizedBox.shrink()
          : OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.edit),
            );
    }
    if (isPassenger && onLeave != null) {
      return OutlinedButton.icon(
        onPressed: isLeaving ? null : onLeave,
        icon: const Icon(Icons.logout),
        label: Text(isLeaving ? l.leaving : l.leave),
      );
    }
    if (onJoin != null && unavailableReason == null) {
      return FilledButton.icon(
        onPressed: isJoining ? null : onJoin,
        icon: isJoining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(
          isJoining
              ? l.joining
              : betaText(context, 'Rejoindre ce trajet', 'Join this ride'),
        ),
      );
    }
    // Full capacity is already shown once above; other reasons stay explicit.
    if (unavailableReason != null &&
        !(carpool.isFull && unavailableReason == l.carpoolFull)) {
      return Text(
        unavailableReason!,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openMap(BuildContext context, CarpoolModel carpool) async {
    final encoded = Uri.encodeComponent(carpool.origin);
    final lat = carpool.originLatitude;
    final lon = carpool.originLongitude;

    // On Android, try geo: scheme to let the OS/app chooser handle it directly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      Uri geo;
      if (lat != null && lon != null) {
        geo = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
      } else {
        geo = Uri.parse('geo:0,0?q=$encoded');
      }
      try {
        final opened = await launchUrl(
          geo,
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      } catch (_) {
        // fallback to manual choice below
      }
    }

    if (!context.mounted) return;
    final provider = await _pickMapProvider(context);
    if (provider == null) return;
    final uri = _uriForProvider(provider, encoded, lat, lon);

    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && context.mounted) {
        // Simple snackbar since we are in a stateless widget, ideally we'd show a proper error
        // But preventing crash is key.
        debugPrint('Could not launch map url');
      }
    } catch (_) {
      debugPrint('Error launching map');
    }
  }

  Future<String?> _pickMapProvider(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.explore),
              title: Text(S.of(context).mapProviderGoogle),
              onTap: () => Navigator.of(context).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: Text(S.of(context).mapProviderApple),
              onTap: () => Navigator.of(context).pop('apple'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: Text(S.of(context).mapProviderOsm),
              onTap: () => Navigator.of(context).pop('osm'),
            ),
          ],
        ),
      ),
    );
  }

  Uri _uriForProvider(
    String provider,
    String encodedAddress,
    double? lat,
    double? lon,
  ) {
    switch (provider) {
      case 'google':
        if (lat != null && lon != null) {
          return Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
          );
        }
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
        );
      case 'apple':
        if (lat != null && lon != null) {
          return Uri.parse('https://maps.apple.com/?ll=$lat,$lon');
        }
        return Uri.parse('https://maps.apple.com/?q=$encodedAddress');
      default:
        if (lat != null && lon != null) {
          return Uri.parse(
            'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon',
          );
        }
        return Uri.parse(
          'https://www.openstreetmap.org/search?query=$encodedAddress',
        );
    }
  }

  String _formatDepartureTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.yMMMd(locale).add_Hm();
    return formatter.format(dateTime.toLocal());
  }
}

class _DriverAvatar extends StatelessWidget {
  final String? handle;
  final String? avatarUrl;
  final bool isCurrentUser;

  const _DriverAvatar({
    required this.handle,
    required this.avatarUrl,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 20,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    backgroundImage: avatarUrl != null
        ? platformNetworkImage(avatarUrl!)
        : null,
    child: avatarUrl == null
        ? Text(
            (handle?.isNotEmpty == true) ? handle![0].toUpperCase() : '?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          )
        : null,
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final VoidCallback? onTap;
  final IconData? actionIcon;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.onTap,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  decoration: onTap != null ? TextDecoration.underline : null,
                  decorationColor: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          Icon(
            actionIcon ?? Icons.open_in_new,
            size: 16,
            color: theme.colorScheme.onSurface,
          ),
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: content,
    );
  }
}
