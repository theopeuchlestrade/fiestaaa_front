import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/config.dart';
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

    throw apiExceptionFromResponse(
      response,
      fallbackMessage: 'qr_code_load_failed',
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
      throw apiExceptionFromResponse(
        response,
        fallbackMessage: 'qr_scan_forbidden',
      );
    }

    if (response.statusCode == 404) {
      throw apiExceptionFromResponse(response, fallbackMessage: 'qr_not_found');
    }

    throw apiExceptionFromResponse(response, fallbackMessage: 'qr_scan_failed');
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

    throw apiExceptionFromResponse(
      response,
      fallbackMessage: 'qr_stats_load_failed',
    );
  }

  void dispose() {
    _client.close();
  }
}
