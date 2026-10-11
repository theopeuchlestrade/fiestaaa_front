import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/route_back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Context and navigation shared by every independently addressable event module.
class EventModuleHeader extends StatelessWidget {
  const EventModuleHeader({
    super.key,
    required this.title,
    required this.eventName,
    required this.eventId,
    this.locations = const {},
    this.trailing,
  });
  final String title, eventName;
  final int eventId;
  final Map<String, String> locations;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RouteBackButton(fallback: '/events/$eventId'),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(eventName, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (locations.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: S.of(context).formModules,
            icon: const Icon(Icons.dashboard_outlined),
            onSelected: (path) => context.pushReplacement(path),
            itemBuilder: (_) => [
              for (final entry in locations.entries)
                PopupMenuItem(
                  value: entry.value,
                  enabled: entry.key != title,
                  child: Text(entry.key),
                ),
            ],
          ),
        ?trailing,
      ],
    ),
  );
}
