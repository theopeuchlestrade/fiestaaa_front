import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_items_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<EventItemModel> sampleItems() {
    return [
      EventItemModel(
        eventId: 1,
        itemId: 1,
        typeId: 1,
        typeName: 'Boissons',
        name: 'Soda',
        maxQuantity: 10,
        reservedQuantity: 4,
        unitLabel: 'pieces',
        kind: EventItemKind.bring,
        category: EventItemCategory.soft,
        createdByEmail: 'alice@example.com',
        createdByHandle: 'Alice',
        createdByAvatarUrl: null,
      ),
      EventItemModel(
        eventId: 1,
        itemId: 2,
        typeId: 1,
        typeName: 'Boissons',
        name: 'Jus',
        maxQuantity: 8,
        reservedQuantity: 2,
        unitLabel: 'pieces',
        kind: EventItemKind.need,
        category: EventItemCategory.soft,
        createdByEmail: 'owner@example.com',
        createdByHandle: 'Owner',
        createdByAvatarUrl: null,
      ),
      EventItemModel(
        eventId: 1,
        itemId: 3,
        typeId: 2,
        typeName: 'Snacks',
        name: 'Chips',
        maxQuantity: 6,
        reservedQuantity: 1,
        unitLabel: 'packs',
        kind: EventItemKind.need,
        category: EventItemCategory.sale,
        createdByEmail: 'owner@example.com',
        createdByHandle: 'Owner',
        createdByAvatarUrl: null,
      ),
      EventItemModel(
        eventId: 1,
        itemId: 4,
        typeId: 3,
        typeName: 'Desserts',
        name: 'Cake',
        maxQuantity: 5,
        reservedQuantity: 0,
        unitLabel: 'pieces',
        kind: EventItemKind.need,
        category: EventItemCategory.sucre,
        createdByEmail: 'owner@example.com',
        createdByHandle: 'Owner',
        createdByAvatarUrl: null,
      ),
    ];
  }

  Widget buildTestWidget({
    required double width,
    required EventItemCategory? selectedCategory,
    required ValueChanged<EventItemCategory?> onCategoryChanged,
    List<EventItemModel>? items,
    ValueChanged<EventItemModel>? onReserve,
    Map<int, List<ItemContributionModel>>? contributions,
  }) {
    final allItems = items ?? sampleItems();
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: EventItemsGrid(
                items: allItems,
                summary: EventItemCategorySummaryModel.fromItems(allItems),
                selectedCategory: selectedCategory,
                contributions:
                    contributions ?? const <int, List<ItemContributionModel>>{},
                reservingItemId: null,
                deletingItemId: null,
                currentUserEmail: 'alice@example.com',
                canReserveItems: true,
                canDelete: (_) => false,
                onCategoryChanged: onCategoryChanged,
                onReserve: onReserve ?? (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders responsive grid with 2, 3 and 4+ columns', (
    tester,
  ) async {
    EventItemCategory? selected;

    await tester.pumpWidget(
      buildTestWidget(
        width: 390,
        selectedCategory: selected,
        onCategoryChanged: (value) => selected = value,
      ),
    );
    await tester.pumpAndSettle();
    var grid = tester.widget<GridView>(find.byType(GridView).first);
    var delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);

    await tester.pumpWidget(
      buildTestWidget(
        width: 820,
        selectedCategory: selected,
        onCategoryChanged: (value) => selected = value,
      ),
    );
    await tester.pumpAndSettle();
    grid = tester.widget<GridView>(find.byType(GridView).first);
    delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);

    await tester.pumpWidget(
      buildTestWidget(
        width: 1280,
        selectedCategory: selected,
        onCategoryChanged: (value) => selected = value,
      ),
    );
    await tester.pumpAndSettle();
    grid = tester.widget<GridView>(find.byType(GridView).first);
    delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(4));
  });

  testWidgets('filters by category and shows empty state per category', (
    tester,
  ) async {
    EventItemCategory? selectedCategory;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return buildTestWidget(
            width: 390,
            selectedCategory: selectedCategory,
            onCategoryChanged: (value) {
              setState(() => selectedCategory = value);
            },
            items: [sampleItems()[0], sampleItems()[2]],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soda'), findsOneWidget);
    expect(find.text('Chips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('item-category-chip-soft')));
    await tester.pumpAndSettle();

    expect(find.text('Soda'), findsOneWidget);
    expect(find.text('Chips'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('item-category-chip-sucre')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('event-items-empty-sucre')),
      findsOneWidget,
    );
  });

  testWidgets('bring items stay personal and are not shareable', (
    tester,
  ) async {
    var reserveCalls = 0;

    await tester.pumpWidget(
      buildTestWidget(
        width: 390,
        selectedCategory: null,
        onCategoryChanged: (_) {},
        items: [sampleItems()[0]],
        onReserve: (_) => reserveCalls++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Apport personnel'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Je contribue'), findsNothing);
    expect(find.text('Modifier ma contribution'), findsNothing);

    final bringCardFinder = find.ancestor(
      of: find.text('Soda'),
      matching: find.byType(InkWell),
    );
    final bringCard = tester.widget<InkWell>(bringCardFinder.first);
    expect(bringCard.onTap, isNull);
    expect(reserveCalls, 0);
  });

  testWidgets('need items show contributors with names', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        width: 390,
        selectedCategory: null,
        onCategoryChanged: (_) {},
        items: [sampleItems()[1]],
        contributions: {
          2: [
            ItemContributionModel(
              itemId: 2,
              quantity: 2,
              email: 'bob@example.com',
              handle: 'Bob',
              avatarUrl: null,
            ),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
  });
}
