import 'package:fiestaaa_front/src/features/events/presentation/event_items_filters.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_items_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scope chip and sort menu trigger callbacks', (tester) async {
    EventItemsScope? selectedScope;
    EventItemsSort? selectedSort;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventItemsFilterControls(
            selectedScope: EventItemsScope.all,
            selectedSort: EventItemsSort.smart,
            scopeLabelBuilder: (scope) => switch (scope) {
              EventItemsScope.all => 'All',
              EventItemsScope.mine => 'Mine',
              EventItemsScope.toCover => 'To cover',
              EventItemsScope.completed => 'Completed',
            },
            sortLabelBuilder: (sort) => switch (sort) {
              EventItemsSort.smart => 'Smart',
              EventItemsSort.nameAsc => 'Name',
              EventItemsSort.remainingDesc => 'Remaining',
            },
            sortTooltip: 'Sort by',
            onScopeChanged: (scope) => selectedScope = scope,
            onSortChanged: (sort) => selectedSort = sort,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('items_scope_mine')));
    await tester.pumpAndSettle();
    expect(selectedScope, EventItemsScope.mine);

    await tester.tap(find.byKey(const Key('items_sort_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    expect(selectedSort, EventItemsSort.nameAsc);
  });
}
