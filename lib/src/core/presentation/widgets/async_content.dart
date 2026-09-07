import 'package:flutter/material.dart';

/// Shared accessible load, empty and error states. Existing content can remain
/// mounted while a compact failure notice is displayed above it.
class AsyncNotice extends StatelessWidget {
  const AsyncNotice({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.wifi_off,
    this.compact = false,
  });
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          ExcludeSemantics(child: Icon(icon)),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      child: compact
          ? content
          : Center(child: SingleChildScrollView(child: content)),
    );
  }
}

class CountedIcon extends StatelessWidget {
  const CountedIcon({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
  });
  final IconData icon;
  final int count;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: count > 0 ? '$label: $count' : label,
    excludeSemantics: true,
    child: Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    ),
  );
}
