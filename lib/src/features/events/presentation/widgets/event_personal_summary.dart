import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';

class EventPersonalSummary extends StatelessWidget {
  const EventPersonalSummary({
    super.key,
    required this.event,
    required this.email,
    required this.owner,
    required this.accepted,
    required this.waiting,
    required this.invitationKnown,
    required this.items,
    required this.contributions,
    required this.polls,
    required this.onInvitation,
    required this.onItems,
    required this.onPolls,
    required this.onRetry,
  });
  final EventModel event;
  final String email;
  final bool owner, accepted, waiting, invitationKnown;
  final List<EventItemModel>? items;
  final List<ItemContributionModel>? contributions;
  final List<PollModel>? polls;
  final VoidCallback onInvitation, onItems, onPolls, onRetry;
  @override
  Widget build(BuildContext context) {
    if (event.isReadOnly) return const SizedBox.shrink();
    final l = S.of(context);
    final rows = <Widget>[];
    Widget unavailable(String label) => ListTile(
      title: Text(label),
      subtitle: Text(l.eventSummaryUnavailable),
      trailing: IconButton(
        tooltip: l.retry,
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      ),
    );
    if (!owner && !invitationKnown) {
      rows.add(unavailable(l.eventYourInvitation));
    }
    if (!owner && waiting) {
      rows.add(
        ListTile(
          title: Text(l.eventYourInvitation),
          leading: const Icon(Icons.mark_email_unread_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: onInvitation,
        ),
      );
    }
    if (owner || accepted) {
      if (event.enabledFeatures.contains(eventFeaturePolls)) {
        if (polls == null) {
          rows.add(unavailable(l.eventYourPolls));
        } else {
          final pending = polls!
              .where((p) => !p.isExpired && p.myVotes.isEmpty)
              .toList();
          if (pending.isNotEmpty) {
            rows.add(
              ListTile(
                title: Text(l.eventYourPolls),

                leading: const Icon(Icons.poll_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: onPolls,
              ),
            );
          }
        }
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.eventForYou,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}
