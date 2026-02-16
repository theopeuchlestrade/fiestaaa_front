import 'dart:math' as math;

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:flutter/material.dart';

class EventItemsGrid extends StatelessWidget {
  const EventItemsGrid({
    super.key,
    required this.items,
    required this.summary,
    required this.selectedCategory,
    required this.contributions,
    required this.reservingItemId,
    required this.deletingItemId,
    required this.currentUserEmail,
    required this.canReserveItems,
    required this.canDelete,
    required this.onCategoryChanged,
    required this.onReserve,
    required this.onDelete,
  });

  final List<EventItemModel> items;
  final List<EventItemCategorySummaryModel> summary;
  final EventItemCategory? selectedCategory;
  final Map<int, List<ItemContributionModel>> contributions;
  final int? reservingItemId;
  final int? deletingItemId;
  final String currentUserEmail;
  final bool canReserveItems;
  final bool Function(EventItemModel item) canDelete;
  final ValueChanged<EventItemCategory?> onCategoryChanged;
  final ValueChanged<EventItemModel> onReserve;
  final ValueChanged<EventItemModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final filteredItems =
        items
            .where(
              (item) =>
                  selectedCategory == null || item.category == selectedCategory,
            )
            .toList()
          ..sort((a, b) {
            final aFull = a.remaining <= 0;
            final bFull = b.remaining <= 0;
            if (aFull != bFull) return aFull ? 1 : -1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    final summaryByCategory = {for (final item in summary) item.category: item};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).itemCategoriesLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('item-category-chip-all'),
              label: Text(S.of(context).allCategories),
              selected: selectedCategory == null,
              onSelected: (_) => onCategoryChanged(null),
            ),
            ...EventItemCategory.values.map(
              (category) => ChoiceChip(
                key: ValueKey('item-category-chip-${category.apiValue}'),
                label: Text(_categoryLabel(context, category)),
                selected: selectedCategory == category,
                onSelected: (_) => onCategoryChanged(category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          S.of(context).itemSummaryTitle,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: EventItemCategory.values.map((category) {
            final totals =
                summaryByCategory[category] ??
                EventItemCategorySummaryModel(
                  category: category,
                  maxQuantity: 0,
                  reservedQuantity: 0,
                  itemCount: 0,
                  coveredItemCount: 0,
                );
            return _CategorySummaryCard(totals: totals);
          }).toList(),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: filteredItems.isEmpty
              ? _CategoryEmptyState(
                  key: ValueKey(
                    'event-items-empty-${selectedCategory?.apiValue ?? 'all'}',
                  ),
                  category: selectedCategory,
                )
              : LayoutBuilder(
                  key: ValueKey(
                    'event-items-grid-${selectedCategory?.apiValue ?? 'all'}',
                  ),
                  builder: (context, constraints) {
                    final crossAxisCount = _crossAxisCount(
                      constraints.maxWidth,
                    );
                    final mainAxisExtent = _mainAxisExtent(crossAxisCount);
                    return GridView.builder(
                      key: const ValueKey('event-items-grid'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: mainAxisExtent,
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _EventItemGridCard(
                          item: item,
                          isLoading: reservingItemId == item.itemId,
                          isDeleting: deletingItemId == item.itemId,
                          currentUserEmail: currentUserEmail,
                          canReserve: canReserveItems,
                          canDelete: canDelete(item),
                          contributions: contributions[item.itemId] ?? const [],
                          onReserve: () => onReserve(item),
                          onDelete: () => onDelete(item),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  int _crossAxisCount(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    return math.max(4, (width / 250).floor());
  }

  double _mainAxisExtent(int crossAxisCount) {
    if (crossAxisCount <= 2) return 272;
    if (crossAxisCount == 3) return 264;
    return 252;
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.totals});

  final EventItemCategorySummaryModel totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 430;
    final cardWidth = screenWidth < 600 ? (isCompact ? 136.0 : 148.0) : 180.0;
    final accent = theme.colorScheme.primary;
    final ratio = totals.itemCount == 0
        ? 0.0
        : totals.coveredItemCount / totals.itemCount;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _categoryLabel(context, totals.category),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S
                .of(context)
                .itemsCoveredProgress(
                  totals.coveredItemCount,
                  totals.itemCount,
                ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: isCompact ? 5 : 6,
              value: ratio.clamp(0, 1),
              backgroundColor: accent.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            S.of(context).itemsCount(totals.itemCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({super.key, required this.category});

  final EventItemCategory? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    final label = category == null
        ? S.of(context).noItemsYet
        : S.of(context).noItemsForCategory(_categoryLabel(context, category!));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    );
  }
}

class _EventItemGridCard extends StatelessWidget {
  const _EventItemGridCard({
    required this.item,
    required this.isLoading,
    required this.isDeleting,
    required this.currentUserEmail,
    required this.canReserve,
    required this.canDelete,
    required this.contributions,
    required this.onReserve,
    required this.onDelete,
  });

  final EventItemModel item;
  final bool isLoading;
  final bool isDeleting;
  final String currentUserEmail;
  final bool canReserve;
  final bool canDelete;
  final List<ItemContributionModel> contributions;
  final VoidCallback onReserve;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = MediaQuery.of(context).size.width < 430;
    final isBring = item.kind == EventItemKind.bring;
    final canContribute = canReserve && !isBring;
    final ratio = item.maxQuantity == 0
        ? 0.0
        : item.reservedQuantity / item.maxQuantity;
    final isFull = item.remaining <= 0;
    final hasContributed = contributions.any(
      (c) => c.email.toLowerCase() == currentUserEmail.toLowerCase(),
    );

    final surface = theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final textColor = theme.colorScheme.onSurface;
    final mutedText = textColor.withValues(alpha: 0.7);
    final actionColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade100;
    final accentGreen = Colors.green.shade500;
    final avatarBackground = isDark
        ? surface.withValues(alpha: 0.9)
        : Colors.grey.shade200;
    final avatarForeground = isDark
        ? textColor.withValues(alpha: 0.8)
        : Colors.grey.shade800;
    final creator = _creatorName(context);
    final creatorAvatarUrl = item.createdByAvatarUrl?.trim();
    final hasCreatorAvatar =
        creatorAvatarUrl != null && creatorAvatarUrl.isNotEmpty;
    final previewLimit = isCompact ? 2 : 3;
    final visibleContributors = contributions.take(previewLimit).toList();
    final extraContributors = contributions.length - visibleContributors.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (!isLoading && canContribute) ? onReserve : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: isCompact ? 16 : 18,
                      onPressed: isDeleting ? null : onDelete,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 4 : 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ItemTag(label: _categoryLabel(context, item.category)),
                ],
              ),
              if (isBring) ...[
                SizedBox(height: isCompact ? 6 : 8),
                Text(
                  S
                      .of(context)
                      .bringQuantityLabel(item.maxQuantity, item.unitLabel),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  S.of(context).bringPersonalLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accentGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: isCompact ? 6 : 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: avatarBackground,
                      backgroundImage: hasCreatorAvatar
                          ? NetworkImage(creatorAvatarUrl)
                          : null,
                      child: hasCreatorAvatar
                          ? null
                          : Text(
                              _creatorInitial(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: avatarForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        creator,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ] else ...[
                SizedBox(height: isCompact ? 6 : 8),
                Text(
                  '${item.reservedQuantity}/${item.maxQuantity} ${item.unitLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: isCompact ? 7 : 8,
                    value: ratio.clamp(0, 1),
                    backgroundColor: isDark
                        ? Colors.white24
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      ratio <= 0 ? Colors.grey.shade400 : accentGreen,
                    ),
                  ),
                ),
                if (isFull) ...[
                  if (!isCompact) ...[
                    SizedBox(height: isCompact ? 6 : 8),
                    Text(
                      S.of(context).quotaFilled,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
                if (visibleContributors.isNotEmpty) ...[
                  SizedBox(height: isCompact ? 6 : 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...visibleContributors.map(
                        (contributor) => _ContributorChip(
                          name: _contributorName(context, contributor),
                          avatarUrl: contributor.avatarUrl,
                          initial: _contributorInitial(contributor),
                        ),
                      ),
                      if (extraContributors > 0)
                        _ContributorMoreChip(extraCount: extraContributors),
                    ],
                  ),
                ],
                const Spacer(),
                if (isCompact)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Tooltip(
                      message: hasContributed
                          ? S.of(context).editContribution
                          : S.of(context).iContribute,
                      child: IconButton.filledTonal(
                        onPressed: (!isLoading && canContribute)
                            ? onReserve
                            : null,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: textColor,
                        ),
                        icon: isLoading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(textColor),
                                ),
                              )
                            : Icon(
                                hasContributed
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 17,
                                color: hasContributed
                                    ? Colors.green.shade600
                                    : textColor,
                              ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: actionColor,
                            foregroundColor: textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: isCompact ? 8 : 10,
                              horizontal: isCompact ? 8 : 10,
                            ),
                          ),
                          onPressed: (!isLoading && canContribute)
                              ? onReserve
                              : null,
                          icon: isLoading
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      textColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  hasContributed
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: hasContributed
                                      ? Colors.green.shade600
                                      : textColor,
                                ),
                          label: Text(
                            hasContributed
                                ? S.of(context).editContribution
                                : S.of(context).iContribute,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _creatorName(BuildContext context) {
    final handle = item.createdByHandle?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    final email = item.createdByEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    return S.of(context).unknownUser;
  }

  String _creatorInitial() {
    final handle = item.createdByHandle?.trim();
    if (handle != null && handle.isNotEmpty) {
      return handle.substring(0, 1).toUpperCase();
    }
    final email = item.createdByEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  String _contributorName(BuildContext context, ItemContributionModel c) {
    final handle = c.handle?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    final email = c.email.trim();
    if (email.isNotEmpty) return email;
    return S.of(context).unknownUser;
  }

  String _contributorInitial(ItemContributionModel c) {
    final handle = c.handle?.trim();
    if (handle != null && handle.isNotEmpty) {
      return handle.substring(0, 1).toUpperCase();
    }
    final email = c.email.trim();
    if (email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return '?';
  }
}

class _ItemTag extends StatelessWidget {
  const _ItemTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ContributorChip extends StatelessWidget {
  const _ContributorChip({
    required this.name,
    required this.avatarUrl,
    required this.initial,
  });

  final String name;
  final String? avatarUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);
    final avatarBackground = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.9)
        : Colors.grey.shade200;
    final avatarForeground = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
        : Colors.grey.shade800;
    final normalizedAvatar = avatarUrl?.trim();
    final hasAvatar = normalizedAvatar != null && normalizedAvatar.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: avatarBackground,
            backgroundImage: hasAvatar ? NetworkImage(normalizedAvatar) : null,
            child: hasAvatar
                ? null
                : Text(
                    initial,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: avatarForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributorMoreChip extends StatelessWidget {
  const _ContributorMoreChip({required this.extraCount});

  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.primary.withValues(alpha: 0.12);
    final textColor = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$extraCount',
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _categoryLabel(BuildContext context, EventItemCategory category) {
  return switch (category) {
    EventItemCategory.soft => S.of(context).itemCategorySoft,
    EventItemCategory.alcool => S.of(context).itemCategoryAlcool,
    EventItemCategory.sale => S.of(context).itemCategorySale,
    EventItemCategory.sucre => S.of(context).itemCategorySucre,
    EventItemCategory.autre => S.of(context).itemCategoryAutre,
  };
}
