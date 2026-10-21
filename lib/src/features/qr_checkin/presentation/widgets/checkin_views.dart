import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/qr_checkin_models.dart';

/// The same compact page context as the other event modules, with native back.
class CheckinHeader extends StatelessWidget {
  const CheckinHeader({
    super.key,
    required this.title,
    required this.eventName,
  });
  final String title, eventName;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BackButton(),
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
      ],
    ),
  );
}

/// No decorations enter the QR quiet zone, regardless of app theme.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.data,
    required this.remaining,
    this.refreshing = false,
  });
  final QRCodeData data;
  final Duration remaining;
  final bool refreshing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = S.of(context);
    final seconds = remaining.inSeconds.clamp(0, 359999);
    final time =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final formatter = DateFormat.yMMMd(l.localeName).add_Hm();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              l.personalInvitation,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxWidth.clamp(0, 280).toDouble();
                return Semantics(
                  label: l.presentCodeAtEntrance,
                  image: true,
                  child: ExcludeSemantics(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: QrImageView(
                        data: data.qrToken,
                        size: (size - 40).clamp(0, 240).toDouble(),
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              l.presentCodeAtEntrance,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (refreshing)
              const LinearProgressIndicator()
            else
              Text(
                l.codeExpiresIn(time),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            const Divider(),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.viewDetails),
              children: [
                Text(l.qrCodeAutoRefresh, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.generatedOn),
                  subtitle: Text(formatter.format(data.generatedAt.toLocal())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.expiresOn),
                  subtitle: Text(formatter.format(data.expiresAt.toLocal())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera and results occupy distinct regions, so large text cannot cover them.
class CheckinScannerView extends StatelessWidget {
  const CheckinScannerView({
    super.key,
    required this.eventName,
    required this.preview,
    this.controls,
    this.stats,
    this.result,
  });
  final String eventName;
  final Widget preview;
  final Widget? controls, result;
  final QRScanStats? stats;
  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final theme = Theme.of(context);
    return FiestaaaPageLayout(
      maxWidth: 760,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckinHeader(title: l.scanner, eventName: eventName),
            if (stats != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      for (final entry in [
                        (l.invited, stats!.totalInvited),
                        (l.present, stats!.totalCheckedIn),
                        (l.remaining, stats!.pendingCheckins),
                      ])
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${entry.$2}',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(entry.$1, style: theme.textTheme.bodySmall),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (result != null)
              result!
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      preview,
                      IgnorePointer(
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: .72,
                            heightFactor: .72,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.scanQrCode,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (controls != null) ...[const SizedBox(height: 12), controls!],
            ],
          ],
        ),
      ),
    );
  }
}
