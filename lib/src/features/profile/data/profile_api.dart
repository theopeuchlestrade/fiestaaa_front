import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:http/http.dart' as http;

class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ProfileInfo> fetchProfile(String token) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return ProfileInfo.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException('Impossible de récupérer le profil',
        statusCode: response.statusCode);
  }

  Future<bool> checkHandleAvailability(String handle) async {
    final uri = Uri.parse('$apiBaseUrl/handles/availability')
        .replace(queryParameters: {'handle': handle});
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['available'] as bool? ?? false;
    }
    if (response.statusCode == 400) {
      throw ApiException('Handle invalide', statusCode: response.statusCode);
    }
    throw _apiError(response);
  }

  Future<ProfileInfo> updateHandle({
    required String token,
    required String handle,
  }) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/me/handle'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'handle': handle}),
    );

    if (response.statusCode == 200) {
      return ProfileInfo.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 409) {
      throw ApiException('Identifiant déjà pris', statusCode: 409);
    }

    throw _apiError(response);
  }

  Future<ProfileInfo> uploadAvatar({
    required String token,
    required String filename,
    required List<int> bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl/me/avatar'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: filename,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return ProfileInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _apiError(response);
  }

  ApiException _apiError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final details = decoded['details'] as String?;
      final error = decoded['error'] as String? ?? 'Erreur API';
      return ApiException(
        details?.isNotEmpty == true ? details! : error,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiException(
        'Erreur inattendue (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
