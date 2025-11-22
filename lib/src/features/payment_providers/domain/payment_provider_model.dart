class PaymentProviderModel {
  const PaymentProviderModel({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.validationRegex,
    required this.isActive,
  });

  final int id;
  final String name;
  final String urlTemplate;
  final String validationRegex;
  final bool isActive;

  static const defaultValidationRegex = r'^https?://.+$';

  factory PaymentProviderModel.fromJson(Map<String, dynamic> json) {
    return PaymentProviderModel(
      id: (json['provider_id'] as num).toInt(),
      name: json['provider_name'] as String,
      urlTemplate: json['url_template'] as String,
      validationRegex:
          json['validation_regex'] as String? ?? defaultValidationRegex,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  RegExp get compiledValidationRegex {
    try {
      return RegExp(validationRegex);
    } catch (_) {
      return RegExp(defaultValidationRegex);
    }
  }
}
