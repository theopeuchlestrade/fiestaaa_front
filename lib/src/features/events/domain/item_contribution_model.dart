class ItemContributionModel {
  ItemContributionModel({
    required this.itemId,
    required this.quantity,
    required this.email,
    this.handle,
    this.avatarUrl,
  });

  final int itemId;
  final int quantity;
  final String email;
  final String? handle;
  final String? avatarUrl;

  factory ItemContributionModel.fromJson(Map<String, dynamic> json) {
    return ItemContributionModel(
      itemId: (json['item_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      email: json['email'] as String,
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
