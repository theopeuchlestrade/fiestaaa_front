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

enum EventItemCategory {
  soft,
  alcool,
  sale,
  sucre,
  autre;

  String get apiValue => switch (this) {
    EventItemCategory.soft => 'soft',
    EventItemCategory.alcool => 'alcool',
    EventItemCategory.sale => 'sale',
    EventItemCategory.sucre => 'sucre',
    EventItemCategory.autre => 'autre',
  };

  static EventItemCategory fromJson(String? value) {
    final normalized = (value ?? 'autre').toLowerCase();
    return switch (normalized) {
      'soft' => EventItemCategory.soft,
      'alcool' => EventItemCategory.alcool,
      'sale' => EventItemCategory.sale,
      'sucre' => EventItemCategory.sucre,
      _ => EventItemCategory.autre,
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
    required this.category,
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
  final EventItemCategory category;
  final String? createdByEmail;
  final String? createdByHandle;
  final String? createdByAvatarUrl;

  int get remaining => (maxQuantity - reservedQuantity).clamp(0, maxQuantity);

  int get reservedForSummary {
    if (kind == EventItemKind.bring) {
      return maxQuantity;
    }
    return reservedQuantity.clamp(0, maxQuantity);
  }

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
      category: EventItemCategory.fromJson(json['item_category'] as String?),
      createdByEmail: json['created_by_email'] as String?,
      createdByHandle: json['created_by_handle'] as String?,
      createdByAvatarUrl: json['created_by_avatar_url'] as String?,
    );
  }
}

class EventItemCategorySummaryModel {
  const EventItemCategorySummaryModel({
    required this.category,
    required this.maxQuantity,
    required this.reservedQuantity,
    required this.itemCount,
    int? coveredItemCount,
  }) : _coveredItemCount = coveredItemCount;

  final EventItemCategory category;
  final int maxQuantity;
  final int reservedQuantity;
  final int itemCount;
  final int? _coveredItemCount;

  int get coveredItemCount {
    final explicit = _coveredItemCount;
    if (explicit != null) {
      return explicit.clamp(0, itemCount);
    }

    if (itemCount <= 0 || maxQuantity <= 0 || reservedQuantity <= 0) {
      return 0;
    }

    if (reservedQuantity >= maxQuantity) {
      return itemCount;
    }

    final estimated = ((reservedQuantity / maxQuantity) * itemCount).floor();
    return estimated.clamp(0, itemCount);
  }

  int get remaining => (maxQuantity - reservedQuantity).clamp(0, maxQuantity);

  factory EventItemCategorySummaryModel.fromJson(Map<String, dynamic> json) {
    final maxQuantity = (json['max_quantity'] as num?)?.toInt() ?? 0;
    final reservedQuantity = (json['reserved_quantity'] as num?)?.toInt() ?? 0;
    final itemCount = (json['item_count'] as num?)?.toInt() ?? 0;
    final coveredFromBackend = (json['covered_item_count'] as num?)?.toInt();
    final coveredFallback = maxQuantity > 0 && reservedQuantity >= maxQuantity
        ? itemCount
        : 0;
    return EventItemCategorySummaryModel(
      category: EventItemCategory.fromJson(json['category'] as String?),
      maxQuantity: maxQuantity,
      reservedQuantity: reservedQuantity,
      itemCount: itemCount,
      coveredItemCount: coveredFromBackend ?? coveredFallback,
    );
  }

  static List<EventItemCategorySummaryModel> fromItems(
    List<EventItemModel> items,
  ) {
    final byCategory = <EventItemCategory, EventItemCategorySummaryModel>{
      for (final category in EventItemCategory.values)
        category: EventItemCategorySummaryModel(
          category: category,
          maxQuantity: 0,
          reservedQuantity: 0,
          itemCount: 0,
          coveredItemCount: 0,
        ),
    };

    for (final item in items) {
      final current = byCategory[item.category]!;
      final isCovered = item.reservedForSummary >= item.maxQuantity;
      byCategory[item.category] = EventItemCategorySummaryModel(
        category: item.category,
        maxQuantity: current.maxQuantity + item.maxQuantity,
        reservedQuantity: current.reservedQuantity + item.reservedForSummary,
        itemCount: current.itemCount + 1,
        coveredItemCount: current.coveredItemCount + (isCovered ? 1 : 0),
      );
    }

    return EventItemCategory.values
        .map((category) => byCategory[category]!)
        .toList();
  }
}
