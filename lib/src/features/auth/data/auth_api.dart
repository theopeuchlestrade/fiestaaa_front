import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<String> register({required String email}) async {
    final response = await _post('/auth/register', body: {'email': email});

    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['status'] as String? ?? 'verification_pending';
    }

    throw _apiError(response);
  }

  Future<String> verifyEmail(String token) async {
    final response = await _post('/auth/verify-email', body: {'token': token});

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['status'] as String? ?? 'verified';
    }

    throw _apiError(response);
  }

  Future<SessionData> completeRegistration({
    required String token,
    required String password,
    String? handle,
  }) async {
    final response = await _post(
      '/auth/complete-registration',
      body: {
        'token': token,
        'password': password,
        if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
      },
    );

    if (response.statusCode == 200) {
      return _sessionFromResponse(response);
    }

    throw _apiError(response);
  }

  Future<SessionData> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _post(
      '/auth/login',
      body: {'identifier': identifier, 'password': password},
    );

    if (response.statusCode == 200) {
      return _sessionFromResponse(response, fallbackIdentifier: identifier);
    }

    throw _apiError(response);
  }

  Future<SessionData> loginWithProvider({
    required String provider,
    String? idToken,
    String? accessToken,
    String? email,
    String? displayName,
  }) async {
    if ((idToken == null || idToken.isEmpty) &&
        (accessToken == null || accessToken.isEmpty)) {
      throw ApiException('Token OAuth manquant ou invalide');
    }

    final response = await _post(
      '/auth/oauth/$provider',
      body: {
        'idToken': ?idToken,
        'accessToken': ?accessToken,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (displayName != null && displayName.trim().isNotEmpty)
          'name': displayName.trim(),
      },
    );

    if (response.statusCode == 200) {
      return _sessionFromResponse(response, fallbackIdentifier: email);
    }

    throw _apiError(response);
  }

  Future<SessionData?> validateSession(String token) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/me'),
      headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final email = decoded['email'] as String?;
      final handle = decoded['handle'] as String?;
      if (email == null) return null;
      return SessionData(
        token: kIsWeb ? '' : token,
        email: email,
        handle: handle,
      );
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

  Future<void> logout() async {
    await _client.post(Uri.parse('$apiBaseUrl/auth/logout'));
  }

  ApiException _apiError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final details = decoded['details'] as String?;
      final error = decoded['error'] as String? ?? 'Erreur API';
      return ApiException(
        details?.isNotEmpty == true ? details! : error,
        statusCode: response.statusCode,
        code: error,
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

  SessionData _sessionFromResponse(
    http.Response response, {
    String? fallbackIdentifier,
  }) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final token = decoded['token'] as String?;
    final email = decoded['email'] as String? ?? fallbackIdentifier;
    final handle = decoded['handle'] as String?;
    final resolvedToken = kIsWeb ? '' : token;
    if ((resolvedToken == null || resolvedToken.isEmpty) && !kIsWeb ||
        email == null ||
        email.isEmpty) {
      throw ApiException(
        'Réponse invalide du serveur',
        statusCode: response.statusCode,
      );
    }
    return SessionData(
      token: resolvedToken ?? '',
      email: email,
      handle: handle,
    );
  }
}
