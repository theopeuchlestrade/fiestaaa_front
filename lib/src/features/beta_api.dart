import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_http_client.dart';
import '../core/api_response.dart';
import '../core/config.dart';

class BetaApi {
  BetaApi({http.Client? client}) : _client = client ?? createApiHttpClient();
  final http.Client _client;
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final parsed = Uri.parse(path);
    final uri = buildApiUri(
      parsed.path,
      queryParameters: parsed.queryParameters,
    );
    final response = switch (method) {
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? {}),
      ),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => await _client.get(uri, headers: headers),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw apiExceptionFromResponse(
        response,
        fallbackMessage: 'Request failed',
      );
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  void close() => _client.close();
}
