import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson applies defaults and clamps remaining quantity', () {
    final item = EventItemModel.fromJson({
      'event_id': 1,
      'item_id': 42,
      'type_id': 7,
      'type_name': 'Drinks',
      'name_item': 'Lemonade',
      'max_quantity': 4,
      'reserved_quantity': 8,
      'item_kind': null,
      'unit_label': null,
    });

    expect(item.kind, EventItemKind.need);
    expect(item.unitLabel, 'pièce');
    expect(item.remaining, 0);
  });

  test('isCreatedBy compares emails case-insensitively', () {
    final item = EventItemModel(
      eventId: 1,
      itemId: 2,
      typeId: 3,
      typeName: 'Snacks',
      name: 'Chips',
      maxQuantity: 2,
      reservedQuantity: 1,
      unitLabel: 'packs',
      kind: EventItemKind.bring,
      createdByEmail: 'Owner@Example.com',
      createdByHandle: 'owner',
      createdByAvatarUrl: null,
    );

    expect(item.isCreatedBy('owner@example.com'), isTrue);
    expect(item.isCreatedBy('guest@example.com'), isFalse);
  });

  test('EventItemKind.fromJson maps bring and falls back to need', () {
    expect(EventItemKind.fromJson('BRING'), EventItemKind.bring);
    expect(EventItemKind.fromJson('unknown'), EventItemKind.need);
    expect(EventItemKind.fromJson(null), EventItemKind.need);
  });
}
