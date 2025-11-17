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

  void dispose() {
    _client.close();
  }
}
