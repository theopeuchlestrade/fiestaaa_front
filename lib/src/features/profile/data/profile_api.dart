import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:http/http.dart' as http;

class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<ProfileInfo> fetchProfile(String token) async {
    final response = await _client.get(
      buildApiUri('/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return ProfileInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw apiExceptionFromResponse(
      response,
      fallbackMessage: 'profile_load_failed',
    );
  }

  Future<bool> checkHandleAvailability(String handle) async {
    final uri = buildApiUri(
      '/handles/availability',
      queryParameters: {'handle': handle},
    );
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['available'] as bool? ?? false;
    }
    if (response.statusCode == 400) {
      throw apiExceptionFromResponse(
        response,
        fallbackMessage: 'invalid_handle',
      );
    }
    throw _apiError(response);
  }

  Future<ProfileInfo> updateHandle({
    required String token,
    required String handle,
  }) async {
    final response = await _client.patch(
      buildApiUri('/me/handle'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'handle': handle}),
    );

    if (response.statusCode == 200) {
      return ProfileInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    if (response.statusCode == 409) {
      throw apiExceptionFromResponse(response, fallbackMessage: 'handle_taken');
    }

    throw _apiError(response);
  }

  Future<ProfileInfo> uploadAvatar({
    required String token,
    required String filename,
    required List<int> bytes,
  }) async {
    final request = http.MultipartRequest('POST', buildApiUri('/me/avatar'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
      );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return ProfileInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _apiError(response);
  }

  Future<void> deleteAccount({required String token}) async {
    final response = await _client.delete(
      buildApiUri('/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw _apiError(response);
  }

  ApiException _apiError(http.Response response) => apiExceptionFromResponse(
    response,
    fallbackMessage: 'profile_request_failed',
  );

  void dispose() {
    _client.close();
  }
}
