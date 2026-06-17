import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
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
    final response = await _client.get(uri, headers: apiAuthHeaders(token));

    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<List<dynamic>>(response);
      return decoded
          .map((e) => AddressSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible de vérifier l’adresse',
    );
  }

  Future<List<EventModel>> fetchEvents({required String token}) async {
    final response = await _client.get(
      buildApiUri('/events'),
      headers: apiAuthHeaders(token),
    );
    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<List<dynamic>>(response);
      return decoded
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _apiError(
      response,
      fallbackMessage: 'Impossible de récupérer les fiestaaa',
    );
  }

  Future<EventModel> createEvent({
    required String token,
    required EventPayload payload,
  }) async {
    final response = await _client.post(
      buildApiUri('/events'),
      headers: apiJsonHeaders(token: token),
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 201) {
      return EventModel.fromJson(
        decodeJsonBody<Map<String, dynamic>>(response),
      );
    }

    throw _apiError(response, fallbackMessage: 'Création impossible');
  }

  Future<EventModel> updateEvent({
    required String token,
    required int eventId,
    required EventPayload payload,
  }) async {
    final response = await _client.put(
      buildApiUri('/events/$eventId'),
      headers: apiJsonHeaders(token: token),
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode == 200) {
      return EventModel.fromJson(
        decodeJsonBody<Map<String, dynamic>>(response),
      );
    }

    throw _apiError(response, fallbackMessage: 'Mise à jour impossible');
  }

  Future<EventModel> fetchEventById({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId'),
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      return EventModel.fromJson(
        decodeJsonBody<Map<String, dynamic>>(response),
      );
    }

    throw _apiError(response, fallbackMessage: 'Fiestaaa introuvable');
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
      headers.addAll(apiAuthHeaders(token));
    }
    final response = await _client.get(
      uri,
      headers: headers.isEmpty ? null : headers,
    );
    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<List<dynamic>>(response);
      return decoded
          .map((e) => EventItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _apiError(
      response,
      fallbackMessage: 'Impossible de récupérer les items',
    );
  }

  Future<List<PollModel>> fetchEventPolls({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/polls'),
      headers: apiAuthHeaders(token),
    );
    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<List<dynamic>>(response);
      return decoded
          .map((e) => PollModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _apiError(
      response,
      fallbackMessage: 'Impossible de charger les sondages',
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
      headers: apiJsonHeaders(token: token),
      body: jsonEncode({
        'question': question,
        'options': options,
        'duration_minutes': durationMinutes,
        'allow_multiple': allowMultiple,
      }),
    );

    if (response.statusCode == 201) {
      return PollModel.fromJson(decodeJsonBody<Map<String, dynamic>>(response));
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible de créer le sondage',
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
      headers: apiJsonHeaders(token: token),
      body: jsonEncode({'option_ids': optionIds}),
    );

    if (response.statusCode == 200) {
      return PollModel.fromJson(decodeJsonBody<Map<String, dynamic>>(response));
    }

    if (response.statusCode == 410) {
      throw ApiException(
        'Ce sondage est expiré.',
        statusCode: response.statusCode,
      );
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible d’enregistrer le vote',
    );
  }

  Future<void> deleteEventPoll({
    required String token,
    required int eventId,
    required int pollId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/events/$eventId/polls/$pollId'),
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _apiError(
      response,
      fallbackMessage: 'Impossible de supprimer le sondage',
    );
  }

  Future<List<ItemContributionModel>> fetchEventItemContributions({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/items/contributions'),
      headers: apiAuthHeaders(token),
    );
    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<List<dynamic>>(response);
      return decoded
          .map((e) => ItemContributionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _apiError(
      response,
      fallbackMessage: 'Impossible de charger les contributions',
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
      headers: apiJsonHeaders(token: token),
      body: jsonEncode({'quantity': quantity}),
    );

    if (response.statusCode == 200) {
      return EventItemModel.fromJson(
        decodeJsonBody<Map<String, dynamic>>(response),
      );
    }

    throw _apiError(response, fallbackMessage: 'Impossible de réserver');
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
      headers: apiJsonHeaders(token: token),
      body: jsonEncode({
        'name_item': name,
        'max_quantity': maxQuantity,
        'unit_label': unitLabel,
        if (itemKind != null) 'item_kind': itemKind.apiValue,
      }),
    );

    if (response.statusCode == 200) {
      return EventItemModel.fromJson(
        decodeJsonBody<Map<String, dynamic>>(response),
      );
    }

    throw _apiError(response, fallbackMessage: 'Impossible d’ajouter l’item');
  }

  Future<void> deleteEventItem({
    required String token,
    required int eventId,
    required int itemId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/events/$eventId/items/$itemId'),
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _apiError(response, fallbackMessage: 'Suppression impossible');
  }

  Future<String> createShareLink({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/share'),
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 201) {
      final decoded = decodeJsonBody<Map<String, dynamic>>(response);
      return decoded['token'] as String;
    }

    throw _apiError(response, fallbackMessage: 'Impossible de générer le lien');
  }

  Future<EventModel> claimShareToken({
    required String token,
    required String shareToken,
  }) async {
    final response = await _client.post(
      buildApiUri('/share/claim'),
      headers: apiJsonHeaders(token: token),
      body: jsonEncode({'token': shareToken}),
    );

    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<Map<String, dynamic>>(response);
      final eventJson = decoded['event'] as Map<String, dynamic>;
      return EventModel.fromJson(eventJson);
    }

    throw _apiError(response, fallbackMessage: 'Lien invalide');
  }

  Future<void> deleteEvent({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.delete(
      buildApiUri('/events/$eventId'),
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _apiError(response, fallbackMessage: 'Suppression impossible');
  }

  Future<List<EventExpenseModel>> fetchEventExpenses({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/expenses'),
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      final decoded = decodeJsonBody<List<dynamic>>(response);
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
      headers: apiAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      return EventExpensesSummaryModel.fromJson(
        decodeJsonBody<Map<String, dynamic>>(response),
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
      headers: apiJsonHeaders(token: token),
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
        decodeJsonBody<Map<String, dynamic>>(response),
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
      headers: apiAuthHeaders(token),
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
    return apiExceptionFromResponse(response, fallbackMessage: fallbackMessage);
  }

  void dispose() {
    _client.close();
  }
}
