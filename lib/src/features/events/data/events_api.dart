import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:http/http.dart' as http;

class EventsApi {
  EventsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AddressSuggestion>> searchAddresses({
    required String token,
    required String query,
    int limit = 5,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/geo/address-search').replace(
      queryParameters: {
        'q': query,
        'limit': '$limit',
      },
    );
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => AddressSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(
      'Impossible de vérifier l’adresse (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<EventModel>> fetchEvents({required String token}) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/events'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException('Impossible de récupérer les événements',
        statusCode: response.statusCode);
  }

  Future<EventModel> createEvent({
    required String token,
    required EventPayload payload,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 201) {
      return EventModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(
      'Création impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<EventModel> updateEvent({
    required String token,
    required int eventId,
    required EventPayload payload,
  }) async {
    final response = await _client.put(
      Uri.parse('$apiBaseUrl/events/$eventId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 200) {
      return EventModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Mise à jour impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<EventModel> fetchEventById({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/events/$eventId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return EventModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Événement introuvable (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<EventItemModel>> fetchEventItems(int eventId) async {
    final response =
        await _client.get(Uri.parse('$apiBaseUrl/events/$eventId/items'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => EventItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Impossible de récupérer les items (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<EventItemModel> reserveEventItem({
    required String token,
    required int eventId,
    required int itemId,
    required int quantity,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events/$eventId/items/$itemId/reserve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'quantity': quantity}),
    );

    if (response.statusCode == 200) {
      return EventItemModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Impossible de réserver (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<EventItemModel> createCustomEventItem({
    required String token,
    required int eventId,
    required String name,
    required int maxQuantity,
    required String unitLabel,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events/$eventId/items/custom'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name_item': name,
        'max_quantity': maxQuantity,
        'unit_label': unitLabel,
      }),
    );

    if (response.statusCode == 200) {
      return EventItemModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Impossible d’ajouter l’item (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteEventItem({
    required String token,
    required int eventId,
    required int itemId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/events/$eventId/items/$itemId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return;
    }

    throw ApiException(
      'Suppression impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<String> createShareLink({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events/$eventId/share'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['token'] as String;
    }

    throw ApiException(
      'Impossible de générer le lien (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<EventModel> claimShareToken({
    required String token,
    required String shareToken,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/share/claim'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'token': shareToken}),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final eventJson = decoded['event'] as Map<String, dynamic>;
      return EventModel.fromJson(eventJson);
    }

    throw ApiException(
      'Lien invalide (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteEvent({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/events/$eventId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return;
    }

    throw ApiException(
      'Suppression impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
