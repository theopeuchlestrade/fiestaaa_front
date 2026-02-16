import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary counts bring items as already covered', () {
    final items = [
      EventItemModel(
        eventId: 1,
        itemId: 1,
        typeId: 1,
        typeName: 'Snacks',
        name: 'Jambon',
        maxQuantity: 20,
        reservedQuantity: 0,
        unitLabel: 'g',
        kind: EventItemKind.bring,
        category: EventItemCategory.sale,
        createdByEmail: 'alice@example.com',
        createdByHandle: 'Alice',
        createdByAvatarUrl: null,
      ),
      EventItemModel(
        eventId: 1,
        itemId: 2,
        typeId: 1,
        typeName: 'Snacks',
        name: 'Pain',
        maxQuantity: 10,
        reservedQuantity: 4,
        unitLabel: 'pièce',
        kind: EventItemKind.need,
        category: EventItemCategory.sale,
        createdByEmail: 'owner@example.com',
        createdByHandle: 'Owner',
        createdByAvatarUrl: null,
      ),
    ];

    final summary = EventItemCategorySummaryModel.fromItems(items);
    final sale = summary.firstWhere(
      (entry) => entry.category == EventItemCategory.sale,
    );

    expect(sale.itemCount, 2);
    expect(sale.coveredItemCount, 1);
    expect(sale.maxQuantity, 30);
    expect(sale.reservedQuantity, 24);
  });
}
