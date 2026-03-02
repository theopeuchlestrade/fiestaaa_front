import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/event_items_filters.dart';
import 'package:flutter_test/flutter_test.dart';

EventItemModel _item({
  required int id,
  required String name,
  required EventItemKind kind,
  required int maxQuantity,
  required int reservedQuantity,
  String? createdByEmail,
}) {
  return EventItemModel(
    eventId: 1,
    itemId: id,
    typeId: 1,
    typeName: 'Type',
    name: name,
    maxQuantity: maxQuantity,
    reservedQuantity: reservedQuantity,
    unitLabel: 'unit',
    kind: kind,
    createdByEmail: createdByEmail,
    createdByHandle: null,
    createdByAvatarUrl: null,
  );
}

void main() {
  test('smart sort puts my bring items first', () {
    final sorted = sortBringItems(
      items: [
        _item(
          id: 1,
          name: 'Chips',
          kind: EventItemKind.bring,
          maxQuantity: 1,
          reservedQuantity: 0,
          createdByEmail: 'other@example.com',
        ),
        _item(
          id: 2,
          name: 'Water',
          kind: EventItemKind.bring,
          maxQuantity: 1,
          reservedQuantity: 0,
          createdByEmail: 'me@example.com',
        ),
      ],
      sort: EventItemsSort.smart,
      currentUserEmail: 'me@example.com',
    );

    expect(sorted.map((e) => e.itemId).toList(), [2, 1]);
  });

  test('smart sort puts open need items before completed ones', () {
    final sorted = sortNeedItems(
      items: [
        _item(
          id: 10,
          name: 'Ice',
          kind: EventItemKind.need,
          maxQuantity: 3,
          reservedQuantity: 3,
        ),
        _item(
          id: 11,
          name: 'Soda',
          kind: EventItemKind.need,
          maxQuantity: 5,
          reservedQuantity: 2,
        ),
      ],
      sort: EventItemsSort.smart,
    );

    expect(sorted.map((e) => e.itemId).toList(), [11, 10]);
  });

  test('remaining sort prioritizes highest remaining quantity', () {
    final sorted = sortNeedItems(
      items: [
        _item(
          id: 20,
          name: 'Bread',
          kind: EventItemKind.need,
          maxQuantity: 10,
          reservedQuantity: 7,
        ),
        _item(
          id: 21,
          name: 'Juice',
          kind: EventItemKind.need,
          maxQuantity: 10,
          reservedQuantity: 2,
        ),
      ],
      sort: EventItemsSort.remainingDesc,
    );

    expect(sorted.map((e) => e.itemId).toList(), [21, 20]);
  });
}
