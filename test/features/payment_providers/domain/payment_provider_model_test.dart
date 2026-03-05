import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson applies defaults for optional payment provider fields', () {
    final provider = PaymentProviderModel.fromJson({
      'provider_id': 1,
      'provider_name': 'Stripe',
      'url_template': 'https://example.com/{identifier}',
    });

    expect(
      provider.validationRegex,
      PaymentProviderModel.defaultValidationRegex,
    );
    expect(provider.isActive, isTrue);
  });

  test('compiledValidationRegex falls back when regex is invalid', () {
    final provider = PaymentProviderModel.fromJson({
      'provider_id': 1,
      'provider_name': 'Broken',
      'url_template': 'https://example.com/{identifier}',
      'validation_regex': '[invalid',
      'is_active': false,
    });

    expect(
      provider.compiledValidationRegex.hasMatch('https://pay.example.com'),
      isTrue,
    );
    expect(provider.isActive, isFalse);
  });
}
