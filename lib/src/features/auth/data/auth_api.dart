import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> register({
    required String email,
    required String password,
    String? handle,
  }) async {
    final response = await _post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
      },
    );

    if (response.statusCode == 201) {
      return;
    }

    throw _apiError(response);
  }

  Future<SessionData> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _post(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final token = decoded['token'] as String?;
      final email = decoded['email'] as String?;
      final handle = decoded['handle'] as String?;
      if (token == null || token.isEmpty) {
        throw ApiException('Réponse invalide du serveur', statusCode: 200);
      }
      return SessionData(
        token: token,
        email: email ?? identifier,
        handle: handle,
      );
    }

    throw _apiError(response);
  }

  Future<SessionData?> validateSession(String token) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final email = decoded['email'] as String?;
      final handle = decoded['handle'] as String?;
      if (email == null) return null;
      return SessionData(token: token, email: email, handle: handle);
    }
    if (response.statusCode == 401) {
      return null;
    }

    throw _apiError(response);
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> body,
  }) {
    final uri = Uri.parse('$apiBaseUrl$path');
    return _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
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
