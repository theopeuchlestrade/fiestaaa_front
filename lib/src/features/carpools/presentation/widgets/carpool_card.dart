import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final l10n = S.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Driver info + Seats indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        carpool.driverHandle ?? l10n.unknownDriver,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isDriver)
                        _StatusBadge(
                          label: l10n.youAreDriver,
                          color: FiestaaaPalette.primary,
                          icon: Icons.directions_car,
                        )
                      else if (isPassenger)
                        _StatusBadge(
                          label: l10n.youArePassenger,
                          color: Colors.teal,
                          icon: Icons.person,
                        ),
                    ],
                  ),
                ),
                _SeatsIndicator(
                  seatsTaken: carpool.seatsTaken,
                  seatsTotal: carpool.seatsTotal,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location and time info
            _InfoRow(
              icon: Icons.location_on_outlined,
              iconColor: FiestaaaPalette.primary,
              text: carpool.origin,
              onTap: () => _openMap(context, carpool),
              actionIcon: Icons.map_outlined,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.schedule_outlined,
              iconColor: FiestaaaPalette.secondary,
              text: _formatDepartureTime(context, carpool.departAt),
              secondaryText: _formatRelativeTime(context, carpool.departAt),
            ),

            // Notes section
            if (carpool.notes != null && carpool.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final notes = carpool.notes!.trim();
                  // Simple check: longer than ~60 chars might need expansion?
                  // Or just use the truncation and allow tap to expand.
                  final isLong = notes.length > 50 || notes.contains('\n');
                  
                  return InkWell(
                    onTap: () => _showFullNotes(context, notes),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : FiestaaaPalette.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : FiestaaaPalette.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: FiestaaaPalette.primary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notes,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (isLong) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                l10n.seeMore, // "Voir plus" (make sure to have this or hardcode for now if missing)
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            // Passengers section
            if (carpool.passengers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.passengersCount(carpool.passengers.length),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: carpool.passengers.map((passenger) {
                  return _PassengerChip(
                    handle: passenger.handle,
                    avatarUrl: passenger.avatarUrl,
                  );
                }).toList(),
              ),
            ],

            // Actions section
            const SizedBox(height: 16),
            _buildActions(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, S l10n) {
    final showJoinButton = onJoin != null && unavailableReason == null;

    return Row(
      children: [
        if (showJoinButton)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isJoining ? null : onJoin,
              icon: isJoining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add, size: 18),
              label: Text(
                isJoining ? l10n.joining : l10n.join,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else if (isPassenger && onLeave != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLeaving ? null : onLeave,
              icon: isLeaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, size: 18),
              label: Text(
                isLeaving ? l10n.leaving : l10n.leave,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else if (unavailableReason != null && !isDriver && !isPassenger)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      unavailableReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isDriver) ...[
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            _ActionIconButton(
              icon: Icons.edit_outlined,
              tooltip: l10n.edit,
              onPressed: onEdit!,
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            _ActionIconButton(
              icon: Icons.delete_outline,
              tooltip: l10n.delete,
              onPressed: onDelete!,
              color: Colors.red.shade400,
            ),
          ],
        ],
      ],
    );
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
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Uri _uriForProvider(String provider, String encodedAddress, double? lat, double? lon) {
    switch (provider) {
      case 'google':
        if (lat != null && lon != null) {
          return Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
        }
        return Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
      case 'apple':
        if (lat != null && lon != null) {
          return Uri.parse('https://maps.apple.com/?ll=$lat,$lon');
        }
        return Uri.parse('https://maps.apple.com/?q=$encodedAddress');
      default:
        if (lat != null && lon != null) {
          return Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon');
        }
        return Uri.parse('https://www.openstreetmap.org/search?query=$encodedAddress');
    }
  }

  String _formatDepartureTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.yMMMMEEEEd(locale).add_Hm();
    return formatter.format(dateTime.toLocal());
  }

  String _formatRelativeTime(BuildContext context, DateTime dateTime) {
    final l10n = S.of(context);
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      return l10n.alreadyPassed;
    } else if (difference.inMinutes < 60) {
      return l10n.inMinutes(difference.inMinutes);
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return minutes > 0 
          ? l10n.inHoursAndMinutes(hours, minutes) 
          : l10n.inHours(hours);
    } else if (difference.inDays == 1) {
      return l10n.tomorrow;
    } else {
      return l10n.inDays(difference.inDays);
    }
  }

  void _showFullNotes(BuildContext context, String notes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: FiestaaaPalette.primary),
            const SizedBox(width: 10),
            Text(S.of(context).carpoolNotes),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(notes),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).close),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: FiestaaaPalette.primary.withValues(alpha: 0.15),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  (handle?.isNotEmpty == true) ? handle![0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FiestaaaPalette.primary,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        if (isCurrentUser)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: FiestaaaPalette.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final String? secondaryText;
  final VoidCallback? onTap;
  final IconData? actionIcon;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.secondaryText,
    this.onTap,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  decoration: onTap != null ? TextDecoration.underline : null,
                  decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              if (secondaryText != null)
                Text(
                  secondaryText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11,
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
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: content,
    );
  }
}

class _SeatsIndicator extends StatelessWidget {
  final int seatsTaken;
  final int seatsTotal;

  const _SeatsIndicator({
    required this.seatsTaken,
    required this.seatsTotal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final seatsAvailable = seatsTotal - seatsTaken;
    final isFull = seatsTaken >= seatsTotal;
    final progress = seatsTotal > 0 ? seatsTaken / seatsTotal : 0.0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isFull
            ? Colors.red.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFull
              ? Colors.red.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? Colors.red.shade400 : Colors.green.shade500,
                  ),
                  strokeWidth: 3,
                ),
              ),
              Text(
                '$seatsAvailable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isFull ? Colors.red.shade600 : Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.seatsAvailable(seatsAvailable),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isFull ? Colors.red.shade600 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerChip extends StatelessWidget {
  final String? handle;
  final String? avatarUrl;

  const _PassengerChip({
    required this.handle,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: FiestaaaPalette.secondary.withValues(alpha: 0.2),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    (handle?.isNotEmpty == true) ? handle![0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FiestaaaPalette.secondary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            handle ?? l10n.anonymous,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? FiestaaaPalette.primary;
    return Container(
      decoration: BoxDecoration(
        color: buttonColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: buttonColor,
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
      ),
    );
  }
}
