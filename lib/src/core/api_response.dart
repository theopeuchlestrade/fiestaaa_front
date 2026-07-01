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

class InvalidApiResponseException extends ApiException {
  InvalidApiResponseException()
    : super('invalid_response', code: 'invalid_response');
}

class Page<T> {
  const Page({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

Future<List<T>> collectCursorPages<T>({
  required Future<http.Response> Function(String? cursor) request,
  required T Function(Map<String, dynamic> json) decode,
}) async {
  final items = <T>[];
  String? cursor;
  do {
    final response = await request(cursor);
    if (response.statusCode != 200) {
      throw apiExceptionFromResponse(
        response,
        fallbackMessage: 'request_failed',
      );
    }
    final values = decodeJsonBody<List<dynamic>>(response);
    items.addAll(values.map((value) => decode(value as Map<String, dynamic>)));
    cursor = response.headers['x-next-cursor'];
  } while (cursor != null && cursor.isNotEmpty);
  return items;
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
  try {
    return jsonDecode(response.body) as T;
  } on Object {
    throw InvalidApiResponseException();
  }
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
    final error = _nonEmptyString(decoded['error']);
    final message = error ?? '$fallbackMessage (${response.statusCode})';
    return ApiException(message, statusCode: response.statusCode, code: error);
  } catch (_) {
    return ApiException(
      '$fallbackMessage (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
