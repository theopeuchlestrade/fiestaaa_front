import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:http/http.dart' as http;

class InvitationsApi {
  InvitationsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<InvitationModel>> fetchEventInvitations({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/events/$eventId/invitations'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => InvitationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Impossible de charger les invitations',
      statusCode: response.statusCode,
    );
  }

  Future<List<InvitationModel>> fetchMyInvitations(String token) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/my/invitations'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((e) => InvitationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Impossible de charger vos invitations',
      statusCode: response.statusCode,
    );
  }

  Future<InvitationCreationResult> createInvitation({
    required String token,
    required int eventId,
    required String identifier,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events/$eventId/invitations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'event_id': eventId,
        'identifier': identifier,
      }),
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
    throw ApiException('Impossible de créer l’invitation',
        statusCode: response.statusCode);
  }

  Future<InvitationModel> updateInvitation({
    required String token,
    required int eventId,
    required String email,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/my/invitations/$eventId'),
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
    throw ApiException('Impossible de mettre à jour l’invitation',
        statusCode: response.statusCode);
  }

  Future<void> deleteInvitation({
    required String token,
    required int eventId,
    required String email,
  }) async {
    final response = await _client.delete(
      Uri.parse(
        '$apiBaseUrl/events/$eventId/invitations/${Uri.encodeComponent(email)}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw ApiException('Suppression impossible',
          statusCode: response.statusCode);
    }
  }

  Future<InvitationModel> respondInvitation({
    required String token,
    required int eventId,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/my/invitations/$eventId'),
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
    throw ApiException('Action impossible (${response.statusCode})',
        statusCode: response.statusCode);
  }


  void dispose() {
    _client.close();
  }
}
