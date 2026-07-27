import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:http/http.dart' as http;

class InvitationsApi {
  InvitationsApi({http.Client? client})
    : _client = client ?? createApiHttpClient();

  final http.Client _client;

  Future<List<InvitationModel>> fetchEventInvitations({
    required String token,
    required int eventId,
  }) async {
    return collectCursorPages(
      request: (cursor) => _client.get(
        buildApiUri(
          '/events/$eventId/invitations',
          queryParameters: {'limit': '100', 'cursor': ?cursor},
        ),
        headers: apiAuthHeaders(token),
      ),
      decode: InvitationModel.fromJson,
    );
  }

  Future<List<InvitationModel>> fetchMyInvitations(String token) async {
    return collectCursorPages(
      request: (cursor) => _client.get(
        buildApiUri(
          '/my/invitations',
          queryParameters: {'limit': '100', 'cursor': ?cursor},
        ),
        headers: apiAuthHeaders(token),
      ),
      decode: InvitationModel.fromJson,
    );
  }

  Future<InvitationCreationResult> createInvitation({
    required String token,
    required int eventId,
    required String identifier,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/invitations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'event_id': eventId, 'identifier': identifier}),
    );
    if (response.statusCode == 201) {
      return InvitationCreationResult.invitation(
        InvitationModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ),
      );
    }
    if (response.statusCode == 202) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final status = decoded['status'] as String?;
      return InvitationCreationResult.emailSent(
        message: status == null
            ? null
            : (status == 'email_sent'
                  ? 'Invitation envoyée par email'
                  : status),
      );
    }
    throw _apiError(
      response,
      fallbackMessage: 'Impossible de créer l’invitation',
    );
  }

  Future<InvitationModel> updateInvitation({
    required String token,
    required int eventId,
    required String email,
    required String status,
  }) async {
    final response = await _client.patch(
      buildApiUri('/my/invitations/$eventId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      return InvitationModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(
      'Impossible de mettre à jour l’invitation',
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteInvitation({
    required String token,
    required int eventId,
    required String email,
    int? invitationId,
  }) async {
    final identifier = invitationId?.toString() ?? email;
    final response = await _client.delete(
      buildApiUri(
        '/events/$eventId/invitations/${Uri.encodeComponent(identifier)}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw _apiError(response, fallbackMessage: 'Suppression impossible');
    }
  }

  Future<InvitationModel> respondInvitation({
    required String token,
    required int eventId,
    required String status,
  }) async {
    final response = await _client.patch(
      buildApiUri('/my/invitations/$eventId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      return InvitationModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _apiError(response, fallbackMessage: 'Action impossible');
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
