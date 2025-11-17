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
  }) async {
    final response = await _post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 201) {
      return;
    }

    throw _apiError(response);
  }

  Future<SessionData> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final token = decoded['token'] as String?;
      if (token == null || token.isEmpty) {
        throw ApiException('Réponse invalide du serveur', statusCode: 200);
      }
      return SessionData(token: token, email: email);
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
