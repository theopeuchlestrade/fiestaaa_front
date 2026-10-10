part of '../pages/event_detail_page.dart';

class _EventDetailFeatureActionData {
  const _EventDetailFeatureActionData({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _EventDetailFeatureActionButton extends StatelessWidget {
  const _EventDetailFeatureActionButton({required this.data});

  final _EventDetailFeatureActionData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(data.icon, color: colorScheme.primary),
        title: Text(
          data.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: data.onPressed,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
