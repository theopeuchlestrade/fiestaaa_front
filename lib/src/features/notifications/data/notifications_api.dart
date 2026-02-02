import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:http/http.dart' as http;

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';

class NotificationsApi {
  NotificationsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> registerDevice({
    required String authToken,
    required String fcmToken,
    required String platform,
    String? locale,
    String? appVersion,
  }) async {
    final resp = await _client.post(
      Uri.parse('$apiBaseUrl/me/devices'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': fcmToken,
        'platform': platform,
        if (locale != null) 'locale': locale,
        if (appVersion != null) 'app_version': appVersion,
      }),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw ApiException(
      'Enregistrement du device impossible',
      statusCode: resp.statusCode,
    );
  }

  Future<void> refreshDevice({
    required String authToken,
    required String oldToken,
    required String newToken,
    required String platform,
    String? locale,
    String? appVersion,
  }) async {
    final resp = await _client.post(
      Uri.parse('$apiBaseUrl/me/devices/refresh'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'old_token': oldToken,
        'new_token': newToken,
        'platform': platform,
        if (locale != null) 'locale': locale,
        if (appVersion != null) 'app_version': appVersion,
      }),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw ApiException(
      'Rafraîchissement du device impossible',
      statusCode: resp.statusCode,
    );
  }

  Future<void> deleteDevice({
    required String authToken,
    required String fcmToken,
  }) async {
    final resp = await _client.delete(
      Uri.parse('$apiBaseUrl/me/devices/$fcmToken'),
      headers: {'Authorization': 'Bearer $authToken'},
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw ApiException(
      'Suppression du device impossible',
      statusCode: resp.statusCode,
    );
  }
}
