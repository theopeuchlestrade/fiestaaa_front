import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class RealtimeStatusBanner extends StatelessWidget {
  const RealtimeStatusBanner({
    super.key,
    required this.stream,
    required this.child,
  });

  final Stream<Map<String, dynamic>>? stream;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ancestor = context
        .findAncestorWidgetOfExactType<RealtimeStatusBanner>();
    if (ancestor != null && ancestor.stream == stream) return child;
    return StreamBuilder<Map<String, dynamic>>(
      stream: stream?.where((message) => message['type'] == 'realtime.status'),
      builder: (context, snapshot) {
        final state = snapshot.data?['state'];
        final interrupted = state == 'interrupted' || state == 'disabled';
        return Stack(
          children: [
            child,
            if (interrupted)
              Positioned(
                top: 4,
                right: 8,
                left: 8,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          state == 'disabled'
                              ? S.of(context).realtimeDisabled
                              : S.of(context).realtimeInterrupted,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
