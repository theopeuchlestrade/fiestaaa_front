import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:http/http.dart' as http;

class CarpoolsApi {
  CarpoolsApi({http.Client? client})
    : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<List<CarpoolModel>> fetchEventCarpools({
    required String token,
    required int eventId,
    String? sortBy,
  }) async {
    return collectCursorPages(
      request: (cursor) => _client.get(
        buildApiUri(
          '/events/$eventId/carpools',
          queryParameters: {'limit': '100', 'cursor': ?cursor, 'sort': ?sortBy},
        ),
        headers: apiAuthHeaders(token),
      ),
      decode: CarpoolModel.fromJson,
    );
  }

  Future<CarpoolModel> createCarpool({
    required String token,
    required int eventId,
    required CarpoolPayload payload,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/carpools'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 201) {
      return CarpoolModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Création impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<CarpoolModel> updateCarpool({
    required String token,
    required int carpoolId,
    required CarpoolPatchPayload payload,
  }) async {
    final response = await _client.patch(
      buildApiUri('/carpools/$carpoolId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 200) {
      return CarpoolModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Mise à jour impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteCarpool({
    required String token,
    required int carpoolId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/carpools/$carpoolId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Suppression impossible (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> joinCarpool({
    required String token,
    required int carpoolId,
  }) async {
    final response = await _client.post(
      buildApiUri('/carpools/$carpoolId/join'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Inscription impossible (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> leaveCarpool({
    required String token,
    required int carpoolId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/carpools/$carpoolId/join'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Désinscription impossible (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
