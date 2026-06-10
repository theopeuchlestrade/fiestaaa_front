import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_expense_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:http/http.dart' as http;

class EventsApi {
  EventsApi({http.Client? client}) : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<List<AddressSuggestion>> searchAddresses({
    required String token,
    required String query,
    int limit = 5,
  }) async {
    final uri = buildApiUri(
      '/geo/address-search',
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

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
      buildApiUri('/events'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Impossible de récupérer les fiestaaa',
      statusCode: response.statusCode,
    );
  }

  Future<EventModel> createEvent({
    required String token,
    required EventPayload payload,
  }) async {
    final response = await _client.post(
      buildApiUri('/events'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 201) {
      return EventModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
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
      buildApiUri('/events/$eventId'),
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
      buildApiUri('/events/$eventId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return EventModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Fiestaaa introuvable (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<EventItemModel>> fetchEventItems(
    int eventId, {
    String? token,
    String? scope,
  }) async {
    final uri = buildApiUri(
      '/events/$eventId/items',
      queryParameters: scope == null ? null : {'scope': scope},
    );
    final headers = <String, String>{};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await _client.get(
      uri,
      headers: headers.isEmpty ? null : headers,
    );
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

  Future<List<PollModel>> fetchEventPolls({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/polls'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => PollModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Impossible de charger les sondages (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<PollModel> createEventPoll({
    required String token,
    required int eventId,
    required String question,
    required List<String> options,
    required int durationMinutes,
    bool allowMultiple = true,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/polls'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'question': question,
        'options': options,
        'duration_minutes': durationMinutes,
        'allow_multiple': allowMultiple,
      }),
    );

    if (response.statusCode == 201) {
      return PollModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Impossible de créer le sondage (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<PollModel> votePoll({
    required String token,
    required int eventId,
    required int pollId,
    required List<int> optionIds,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/polls/$pollId/vote'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'option_ids': optionIds}),
    );

    if (response.statusCode == 200) {
      return PollModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 410) {
      throw ApiException(
        'Ce sondage est expiré.',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Impossible d’enregistrer le vote (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteEventPoll({
    required String token,
    required int eventId,
    required int pollId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/events/$eventId/polls/$pollId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw ApiException(
      'Impossible de supprimer le sondage (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<ItemContributionModel>> fetchEventItemContributions({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/items/contributions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => ItemContributionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Impossible de charger les contributions',
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
      buildApiUri('/events/$eventId/items/$itemId/reserve'),
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
    EventItemKind? itemKind,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/items/custom'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name_item': name,
        'max_quantity': maxQuantity,
        'unit_label': unitLabel,
        if (itemKind != null) 'item_kind': itemKind.apiValue,
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
      buildApiUri('/events/$eventId/items/$itemId'),
      headers: {'Authorization': 'Bearer $token'},
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
      buildApiUri('/events/$eventId/share'),
      headers: {'Authorization': 'Bearer $token'},
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
      buildApiUri('/share/claim'),
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
      buildApiUri('/events/$eventId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw ApiException(
      'Suppression impossible (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<List<EventExpenseModel>> fetchEventExpenses({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/expenses'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((raw) => EventExpenseModel.fromJson(raw as Map<String, dynamic>))
          .toList();
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible de charger les dépenses',
    );
  }

  Future<EventExpensesSummaryModel> fetchEventExpensesSummary({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/expenses/summary'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return EventExpensesSummaryModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible de calculer le partage',
    );
  }

  Future<EventExpenseModel> createEventExpense({
    required String token,
    required int eventId,
    required String title,
    required int amountCents,
    required int paidByUserId,
    required List<int> participantUserIds,
    String? note,
    DateTime? expenseDate,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/expenses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'amount_cents': amountCents,
        'paid_by_user_id': paidByUserId,
        'participant_user_ids': participantUserIds,
        'note': note,
        if (expenseDate != null)
          'expense_date': expenseDate.toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode == 201) {
      return EventExpenseModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible d’ajouter la dépense',
    );
  }

  Future<void> deleteEventExpense({
    required String token,
    required int eventId,
    required int expenseId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/events/$eventId/expenses/$expenseId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible de supprimer la dépense',
    );
  }

  ApiException _apiError(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final details = decoded['details'] as String?;
      final error = decoded['error'] as String?;
      final message = details?.isNotEmpty == true
          ? details!
          : (error?.isNotEmpty == true
                ? error!
                : '$fallbackMessage (${response.statusCode})');
      return ApiException(message, statusCode: response.statusCode);
    } catch (_) {
      return ApiException(
        '$fallbackMessage (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
