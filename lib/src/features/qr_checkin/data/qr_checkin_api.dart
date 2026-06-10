import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
import 'package:http/http.dart' as http;

class QRCheckinApi {
  QRCheckinApi({http.Client? client})
    : _client = client ?? createApiHttpClient();

  final http.Client _client;

  /// Generate or retrieve QR code for the authenticated member
  Future<QRCodeData> fetchMyQRCode({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/my-qr-code'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return QRCodeData.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 403) {
      throw ApiException(
        'Vous n\'êtes pas autorisé à accéder à ce QR code',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Impossible de récupérer le QR code (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Scan a QR code (organizer only)
  Future<QRScanResult> scanQRCode({
    required String token,
    required int eventId,
    required String qrToken,
  }) async {
    final response = await _client.post(
      buildApiUri('/events/$eventId/scan-qr'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'token': qrToken}),
    );

    if (response.statusCode == 200) {
      return QRScanResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 409) {
      // Already scanned
      return QRScanResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 403) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded.containsKey('success')) {
        // It's a QRScanResponse with details
        return QRScanResult.fromJson(decoded);
      }
      throw ApiException('Non autorisé', statusCode: response.statusCode);
    }

    if (response.statusCode == 404) {
      throw ApiException(
        'QR code introuvable',
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Erreur lors du scan (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  /// Get check-in statistics for an event (organizer only)
  Future<QRScanStats> fetchScanStats({
    required String token,
    required int eventId,
  }) async {
    final response = await _client.get(
      buildApiUri('/events/$eventId/qr-scan-stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return QRScanStats.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(
      'Impossible de récupérer les statistiques (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
