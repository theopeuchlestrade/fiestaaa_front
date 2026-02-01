enum EventItemKind {
  need,
  bring;

  String get apiValue => switch (this) {
    EventItemKind.need => 'need',
    EventItemKind.bring => 'bring',
  };

  static EventItemKind fromJson(String? value) {
    final normalized = (value ?? 'need').toLowerCase();
    return switch (normalized) {
      'bring' => EventItemKind.bring,
      _ => EventItemKind.need,
    };
  }
}

class EventItemModel {
  EventItemModel({
    required this.eventId,
    required this.itemId,
    required this.typeId,
    required this.typeName,
    required this.name,
    required this.maxQuantity,
    required this.reservedQuantity,
    required this.unitLabel,
    required this.kind,
    required this.createdByEmail,
    required this.createdByHandle,
    required this.createdByAvatarUrl,
  });

  final int eventId;
  final int itemId;
  final int typeId;
  final String typeName;
  final String name;
  final int maxQuantity;
  final int reservedQuantity;
  final String unitLabel;
  final EventItemKind kind;
  final String? createdByEmail;
  final String? createdByHandle;
  final String? createdByAvatarUrl;

  int get remaining => (maxQuantity - reservedQuantity).clamp(0, maxQuantity);

  bool isCreatedBy(String email) {
    if (createdByEmail == null) return false;
    return createdByEmail!.toLowerCase() == email.toLowerCase();
  }

  factory EventItemModel.fromJson(Map<String, dynamic> json) {
    return EventItemModel(
      eventId: (json['event_id'] as num).toInt(),
      itemId: (json['item_id'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
      typeName: json['type_name'] as String,
      name: json['name_item'] as String,
      maxQuantity: (json['max_quantity'] as num).toInt(),
      reservedQuantity: (json['reserved_quantity'] as num).toInt(),
      unitLabel: (json['unit_label'] as String?) ?? 'pièce',
      kind: EventItemKind.fromJson(json['item_kind'] as String?),
      createdByEmail: json['created_by_email'] as String?,
      createdByHandle: json['created_by_handle'] as String?,
      createdByAvatarUrl: json['created_by_avatar_url'] as String?,
    );
  }
}
