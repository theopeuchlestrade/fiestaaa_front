import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:http/http.dart' as http;

class PaymentProvidersApi {
  PaymentProvidersApi({http.Client? client})
    : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<List<PaymentProviderModel>> fetchProviders() async {
    final response = await _client.get(buildApiUri('/payment-providers'));
    if (response.statusCode != 200) {
      throw ApiException(
        'Chargement des cagnottes impossible (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map(
          (item) => PaymentProviderModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
