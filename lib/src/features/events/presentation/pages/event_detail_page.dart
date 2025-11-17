import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:flutter/material.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailTile(
              icon: Icons.event,
              label: 'Date & heure',
              value: '${event.formattedDate} à ${event.formattedTime}',
            ),
            _DetailTile(
              icon: Icons.place,
              label: 'Adresse',
              value: event.address,
            ),
            _DetailTile(
              icon: Icons.description,
              label: 'Description',
              value: event.description,
            ),
            _DetailTile(
              icon: Icons.payment,
              label: 'Paiement',
              value: _paymentInfo(),
            ),
          ],
        ),
      ),
    );
  }

  String _paymentInfo() {
    if (event.paymentProviderId == null) {
      return 'Aucun fournisseur renseigné';
    }
    final identifier =
        event.paymentIdentifier == null ? '' : ' • ${event.paymentIdentifier}';
    return 'Provider ${event.paymentProviderId}$identifier';
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.deepOrange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
