import 'package:fiestaaa_front/src/features/events/presentation/event_items_filters.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';

class EventItemsFilterControls extends StatelessWidget {
  const EventItemsFilterControls({
    super.key,
    required this.selectedScope,
    required this.selectedSort,
    required this.scopeLabelBuilder,
    required this.sortLabelBuilder,
    required this.onScopeChanged,
    required this.onSortChanged,
    required this.sortTooltip,
  });

  final EventItemsScope selectedScope;
  final EventItemsSort selectedSort;
  final String Function(EventItemsScope scope) scopeLabelBuilder;
  final String Function(EventItemsSort sort) sortLabelBuilder;
  final ValueChanged<EventItemsScope> onScopeChanged;
  final ValueChanged<EventItemsSort> onSortChanged;
  final String sortTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = selectedSort != EventItemsSort.smart;
    final scopeChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EventItemsScope.values
          .map(
            (scope) => ChoiceChip(
              key: Key('items_scope_${scope.name}'),
              label: Text(scopeLabelBuilder(scope)),
              selected: selectedScope == scope,
              onSelected: (selected) {
                if (!selected || selectedScope == scope) return;
                onScopeChanged(scope);
              },
            ),
          )
          .toList(),
    );

    final sortMenu = Container(
      decoration: BoxDecoration(
        color: isActive
            ? FiestaaaPalette.primary.withValues(alpha: 0.12)
            : theme.fiestaaaMutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: FiestaaaPalette.primary.withValues(alpha: 0.3))
            : Border.all(color: theme.fiestaaaSoftBorder),
      ),
      child: PopupMenuButton<EventItemsSort>(
        key: const Key('items_sort_button'),
        tooltip: sortTooltip,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (value) {
          if (value == selectedSort) return;
          onSortChanged(value);
        },
        itemBuilder: (context) => [
          _buildSortMenuItem(
            context: context,
            value: EventItemsSort.smart,
            label: sortLabelBuilder(EventItemsSort.smart),
            icon: Icons.reorder,
            isSelected: selectedSort == EventItemsSort.smart,
          ),
          const PopupMenuDivider(),
          _buildSortMenuItem(
            context: context,
            value: EventItemsSort.nameAsc,
            label: sortLabelBuilder(EventItemsSort.nameAsc),
            icon: Icons.sort_by_alpha,
            isSelected: selectedSort == EventItemsSort.nameAsc,
          ),
          _buildSortMenuItem(
            context: context,
            value: EventItemsSort.remainingDesc,
            label: sortLabelBuilder(EventItemsSort.remainingDesc),
            icon: Icons.trending_up,
            isSelected: selectedSort == EventItemsSort.remainingDesc,
          ),
        ],
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort,
              color: isActive ? FiestaaaPalette.primary : theme.iconTheme.color,
              size: 20,
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: FiestaaaPalette.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: scopeChips),
              const SizedBox(width: 12),
              sortMenu,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [scopeChips, const SizedBox(height: 8), sortMenu],
        );
      },
    );
  }

  PopupMenuItem<EventItemsSort> _buildSortMenuItem({
    required BuildContext context,
    required EventItemsSort value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<EventItemsSort>(
      key: Key('items_sort_${value.name}'),
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? FiestaaaPalette.primary
                : Theme.of(context).fiestaaaMutedText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? FiestaaaPalette.primary : null,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, size: 18, color: FiestaaaPalette.primary),
        ],
      ),
    );
  }
}
