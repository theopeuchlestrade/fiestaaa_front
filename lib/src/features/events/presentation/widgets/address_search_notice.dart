import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AddressSearchNotice extends StatelessWidget {
  const AddressSearchNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addressSearchPrivacy,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            onPressed: () async {
              try {
                final opened = await launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                );
                if (opened || !context.mounted) return;
              } catch (_) {
                if (!context.mounted) return;
              }
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.networkError)));
              }
            },
            child: Text(l10n.addressSearchAttribution),
          ),
        ],
      ),
    );
  }
}
