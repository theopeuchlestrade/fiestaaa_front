class PaymentProviderModel {
  const PaymentProviderModel({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.isActive,
  });

  final int id;
  final String name;
  final String urlTemplate;
  final bool isActive;

  factory PaymentProviderModel.fromJson(Map<String, dynamic> json) {
    return PaymentProviderModel(
      id: (json['provider_id'] as num).toInt(),
      name: json['provider_name'] as String,
      urlTemplate: json['url_template'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
