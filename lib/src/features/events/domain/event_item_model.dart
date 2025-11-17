class EventItemModel {
  EventItemModel({
    required this.eventId,
    required this.itemId,
    required this.typeId,
    required this.typeName,
    required this.name,
    required this.maxQuantity,
    required this.reservedQuantity,
  });

  final int eventId;
  final int itemId;
  final int typeId;
  final String typeName;
  final String name;
  final int maxQuantity;
  final int reservedQuantity;

  int get remaining => (maxQuantity - reservedQuantity).clamp(0, maxQuantity);

  factory EventItemModel.fromJson(Map<String, dynamic> json) {
    return EventItemModel(
      eventId: (json['event_id'] as num).toInt(),
      itemId: (json['item_id'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
      typeName: json['type_name'] as String,
      name: json['name_item'] as String,
      maxQuantity: (json['max_quantity'] as num).toInt(),
      reservedQuantity: (json['reserved_quantity'] as num).toInt(),
    );
  }
}
