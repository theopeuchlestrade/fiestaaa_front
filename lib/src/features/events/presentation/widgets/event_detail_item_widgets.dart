part of '../pages/event_detail_page.dart';

class _NewEventItemData {
  const _NewEventItemData(this.name, this.quantity, this.unit, this.kind);

  final String name;
  final int quantity;
  final String unit;
  final EventItemKind kind;
}

class _EventItemsList extends StatelessWidget {
  const _EventItemsList({
    required this.items,
    required this.emptyLabel,
    required this.reservingItemId,
    required this.deletingItemId,
    required this.onReserve,
    required this.onDelete,
    required this.isOwner,
    required this.currentUserEmail,
    required this.canReserveItems,
    required this.contributions,
  });

  final List<EventItemModel> items;
  final String emptyLabel;
  final int? reservingItemId;
  final int? deletingItemId;
  final void Function(EventItemModel item) onReserve;
  final void Function(EventItemModel item) onDelete;
  final bool isOwner;
  final String currentUserEmail;
  final bool canReserveItems;
  final Map<int, List<ItemContributionModel>> contributions;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final theme = Theme.of(context);
      final surface = theme.colorScheme.surface;
      final border = theme.dividerColor;
      final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: textColor),
        ),
      );
    }

    final grouped = <String, List<EventItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.typeName, () => []).add(item);
    }
    final showTypeHeader = grouped.length > 1;

    return Column(
      children: grouped.entries
          .map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTypeHeader) ...[
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],
                ...entry.value.map(
                  (item) => _EventItemTile(
                    item: item,
                    isLoading: reservingItemId == item.itemId,
                    isDeleting: deletingItemId == item.itemId,
                    canReserve: canReserveItems,
                    onTap: () => onReserve(item),
                    onDelete: (isOwner || item.isCreatedBy(currentUserEmail))
                        ? () => onDelete(item)
                        : null,
                    contributions: contributions[item.itemId] ?? const [],
                    currentUserEmail: currentUserEmail,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _EventItemTile extends StatelessWidget {
  const _EventItemTile({
    required this.item,
    required this.isLoading,
    required this.onTap,
    this.onDelete,
    this.isDeleting = false,
    this.canReserve = true,
    this.contributions = const [],
    required this.currentUserEmail,
  });

  final EventItemModel item;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isDeleting;
  final bool canReserve;
  final List<ItemContributionModel> contributions;
  final String currentUserEmail;

  void _showContributors(
    BuildContext context,
    List<ItemContributionModel> list,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final avatarBackground = theme.fiestaaaAvatarSurface;
        final avatarForeground = theme.colorScheme.onSurface;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).participations,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Text(S.of(context).noContributionsYet)
                else
                  ...list.map(
                    (c) => ListTile(
                      title: Text(_displayName(context, c.handle)),
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: avatarBackground,
                        backgroundImage: c.avatarUrl == null
                            ? null
                            : platformNetworkImage(c.avatarUrl!),
                        child: c.avatarUrl == null
                            ? Text(
                                _displayInitial(context, c.handle),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: avatarForeground,
                                ),
                              )
                            : null,
                      ),
                      subtitle: Text('${c.quantity} ${item.unitLabel}'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = S.of(context);
    final isBring = item.kind == EventItemKind.bring;
    final full = item.remaining <= 0;
    final mine = contributions
        .where((c) => c.email.toLowerCase() == currentUserEmail.toLowerCase())
        .fold<int>(0, (sum, c) => sum + c.quantity);
    final ratio = item.maxQuantity <= 0
        ? 0.0
        : (item.reservedQuantity / item.maxQuantity).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(item.name, style: theme.textTheme.titleMedium),
                ),
                if (onDelete != null && canReserve)
                  IconButton(
                    tooltip: l.delete,
                    onPressed: isDeleting ? null : onDelete,
                    icon: isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (isBring) ...[
              Text(
                l.bringQuantityLabel(item.maxQuantity, item.unitLabel),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: item.createdByAvatarUrl == null
                        ? null
                        : platformNetworkImage(item.createdByAvatarUrl!),
                    child: item.createdByAvatarUrl == null
                        ? Text(
                            _displayInitial(context, item.createdByHandle),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _displayName(context, item.createdByHandle),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                '${item.reservedQuantity} / ${item.maxQuantity} ${item.unitLabel}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Semantics(
                container: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: ratio,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
              ),
              if (full) ...[
                const SizedBox(height: 10),
                Text(
                  betaText(context, 'Besoin couvert', 'Need covered'),
                  style: theme.textTheme.labelLarge,
                ),
              ],
              if (mine > 0) ...[
                const SizedBox(height: 12),
                Text(
                  betaText(
                    context,
                    'Votre contribution : $mine ${item.unitLabel}',
                    'Your contribution: $mine ${item.unitLabel}',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
              if (contributions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showContributors(context, contributions),
                    icon: const Icon(Icons.people_outline),
                    label: Text(
                      betaText(context, 'Qui apporte ?', 'Who is bringing it?'),
                    ),
                  ),
                ),
              ],
              if (canReserve && (!full || mine > 0)) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onTap,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(mine > 0 ? Icons.edit_outlined : Icons.add),
                  label: Text(
                    isLoading
                        ? l.sending
                        : mine > 0
                        ? l.editContribution
                        : l.iContribute,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
