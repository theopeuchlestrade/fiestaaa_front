import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';
import 'package:http/http.dart' as http;

class FriendsApi {
  FriendsApi({http.Client? client}) : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<List<FriendModel>> fetchFriends(String token) async {
    return collectCursorPages(
      request: (cursor) => _client.get(
        buildApiUri(
          '/me/friends',
          queryParameters: {'limit': '100', 'cursor': ?cursor},
        ),
        headers: apiAuthHeaders(token),
      ),
      decode: FriendModel.fromJson,
    );
  }

  Future<List<FriendRequestModel>> fetchRequests(String token) async {
    return collectCursorPages(
      request: (cursor) => _client.get(
        buildApiUri(
          '/friends/requests',
          queryParameters: {'limit': '100', 'cursor': ?cursor},
        ),
        headers: apiAuthHeaders(token),
      ),
      decode: FriendRequestModel.fromJson,
    );
  }

  Future<List<FriendSearchResult>> searchFriends(
    String token,
    String query,
  ) async {
    final uri = buildApiUri('/friends/search', queryParameters: {'q': query});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => FriendSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('Recherche impossible', statusCode: response.statusCode);
  }

  Future<FriendRequestModel> sendRequest({
    required String token,
    required String identifier,
  }) async {
    final response = await _client.post(
      buildApiUri('/friends/requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'identifier': identifier}),
    );
    if (response.statusCode == 201) {
      return FriendRequestModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(
      'Impossible d’envoyer la demande',
      statusCode: response.statusCode,
    );
  }

  Future<FriendRequestModel> respondToRequest({
    required String token,
    required int requestId,
    required String status,
  }) async {
    final response = await _client.patch(
      buildApiUri('/friends/requests/$requestId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      return FriendRequestModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException('Action impossible', statusCode: response.statusCode);
  }

  Future<void> deleteFriend({
    required String token,
    required String identifier,
  }) async {
    final response = await _client.delete(
      buildApiUri('/friends/${Uri.encodeComponent(identifier)}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Suppression impossible',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
