part of '../pages/event_detail_page.dart';

class _NewEventItemData {
  const _NewEventItemData(this.name, this.quantity, this.unit, this.kind);

  final String name;
  final int quantity;
  final String unit;
  final EventItemKind kind;
}

class _EventItemsSection extends StatelessWidget {
  const _EventItemsSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.addLabel,
    this.onAdd,
    this.isAdding = false,
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

  final String title;
  final String subtitle;
  final List<EventItemModel> items;
  final String addLabel;
  final VoidCallback? onAdd;
  final bool isAdding;
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final badgeBackground = theme.colorScheme.primary.withValues(alpha: 0.12);
    final badgeText = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isAdding ? null : onAdd,
                icon: isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(addLabel),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${items.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: badgeText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        _EventItemsList(
          items: items,
          emptyLabel: emptyLabel,
          reservingItemId: reservingItemId,
          deletingItemId: deletingItemId,
          onReserve: onReserve,
          onDelete: onDelete,
          isOwner: isOwner,
          currentUserEmail: currentUserEmail,
          canReserveItems: canReserveItems,
          contributions: contributions,
        ),
      ],
    );
  }
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: textColor),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                            : NetworkImage(c.avatarUrl!),
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
    final surface = theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final textColor = theme.colorScheme.onSurface;
    final mutedText = textColor.withValues(alpha: 0.6);
    final actionBackground = theme.fiestaaaMutedSurface;
    final actionForeground = textColor;
    final avatarBackground = theme.fiestaaaAvatarSurface;
    final avatarForeground = textColor;
    final barBackground = theme.fiestaaaSoftSurface;
    final barEmpty = theme.fiestaaaSoftBorder;
    final shadow = theme.colorScheme.scrim.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.25 : 0.12,
    );
    final dangerStyle = theme.colorScheme.fiestaaaStatus(
      FiestaaaStatusTone.danger,
    );
    final ratio = item.maxQuantity == 0
        ? 0.0
        : item.reservedQuantity / item.maxQuantity;
    final available = item.remaining;
    final contributors = contributions;
    final myContribution = contributors
        .where((c) => c.email.toLowerCase() == currentUserEmail.toLowerCase())
        .toList();
    final isFull = available <= 0;
    final hasContributed = myContribution.isNotEmpty;
    final isBring = item.kind == EventItemKind.bring;
    final accentGreen = theme.colorScheme.fiestaaaSuccess;

    if (isBring) {
      final creatorName = _displayName(context, item.createdByHandle);
      final creatorInitial = _displayInitial(context, item.createdByHandle);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGreen.withValues(alpha: 0.15),
                  border: Border.all(color: accentGreen, width: 2),
                ),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  color: accentGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S
                          .of(context)
                          .bringQuantityLabel(item.maxQuantity, item.unitLabel),
                      style: TextStyle(
                        color: mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.of(context).bringPersonalLabel,
                      style: TextStyle(
                        color: accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: avatarBackground,
                          backgroundImage: item.createdByAvatarUrl == null
                              ? null
                              : NetworkImage(item.createdByAvatarUrl!),
                          child: item.createdByAvatarUrl == null
                              ? Text(
                                  creatorInitial,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: avatarForeground,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            creatorName,
                            style: TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: dangerStyle.background,
                    foregroundColor: dangerStyle.foreground,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isDeleting ? null : onDelete,
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  onTap: (!isLoading && canReserve) ? onTap : null,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasContributed ? accentGreen : Colors.transparent,
                      border: Border.all(
                        color: (hasContributed || isFull)
                            ? accentGreen
                            : textColor.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: hasContributed
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (contributors.isNotEmpty)
                            SizedBox(
                              height: 28,
                              width: 110,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: contributors
                                    .take(4)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final idx = entry.key;
                                      final c = entry.value;
                                      final left = idx * 22.0;
                                      return Positioned(
                                        left: left,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: avatarBackground,
                                          backgroundImage: c.avatarUrl == null
                                              ? null
                                              : NetworkImage(c.avatarUrl!),
                                          child: c.avatarUrl == null
                                              ? Text(
                                                  _displayInitial(
                                                    context,
                                                    c.handle,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: avatarForeground,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          Text(
                            '${item.reservedQuantity}/${item.maxQuantity} ${item.unitLabel}',
                            style: TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: textColor.withValues(alpha: 0.75),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: contributors.isEmpty
                      ? null
                      : () => _showContributors(context, contributors),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(S.of(context).view),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: ratio.clamp(0, 1),
                backgroundColor: barBackground,
                valueColor: AlwaysStoppedAnimation(
                  ratio <= 0 ? barEmpty : accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              available > 0
                  ? S
                        .of(context)
                        .remainingAvailable(
                          available,
                          item.unitLabel,
                          available > 1 ? 's' : '',
                        )
                  : S.of(context).quotaFilled,
              style: TextStyle(
                color: isFull ? accentGreen : mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (canReserve)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: actionBackground,
                        foregroundColor: actionForeground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isLoading ? null : onTap,
                      icon: isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  actionForeground,
                                ),
                              ),
                            )
                          : Icon(
                              hasContributed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: hasContributed
                                  ? accentGreen
                                  : actionForeground,
                            ),
                      label: Text(
                        isLoading
                            ? S.of(context).sending
                            : (hasContributed
                                  ? S.of(context).editContribution
                                  : S.of(context).iContribute),
                      ),
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: dangerStyle.background,
                        foregroundColor: dangerStyle.foreground,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isDeleting ? null : onDelete,
                      child: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
