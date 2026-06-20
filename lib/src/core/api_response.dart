import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

Map<String, String> apiAuthHeaders(String token) {
  return {'Authorization': 'Bearer $token'};
}

Map<String, String> apiJsonHeaders({String? token}) {
  return {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

T decodeJsonBody<T>(http.Response response) {
  return jsonDecode(response.body) as T;
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

ApiException apiExceptionFromResponse(
  http.Response response, {
  required String fallbackMessage,
}) {
  try {
    final decoded = decodeJsonBody<Map<String, dynamic>>(response);
    final details = _nonEmptyString(decoded['details']);
    final error = _nonEmptyString(decoded['error']);
    final message =
        details ?? error ?? '$fallbackMessage (${response.statusCode})';
    return ApiException(message, statusCode: response.statusCode, code: error);
  } catch (_) {
    return ApiException(
      '$fallbackMessage (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
