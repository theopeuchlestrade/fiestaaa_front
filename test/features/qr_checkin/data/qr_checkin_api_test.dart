import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('QR API decodes ticket, scan and statistics responses', () async {
    final api = QRCheckinApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/my-qr-code')) {
          return http.Response(
            jsonEncode({
              'qr_token': 'qr-token',
              'event_id': 7,
              'generated_at': '2030-01-01T10:00:00Z',
              'expires_at': '2030-01-01T10:05:00Z',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/scan-qr')) {
          expect(jsonDecode(request.body), {'token': 'qr-token'});
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'checked_in',
              'user_email': 'alice@example.com',
              'message': 'ok',
            }),
            200,
          );
        }
        return http.Response(
          '{"total_invited":10,"total_checked_in":4,"pending_checkins":6}',
          200,
        );
      }),
    );

    final ticket = await api.fetchMyQRCode(token: 'token', eventId: 7);
    final scan = await api.scanQRCode(
      token: 'token',
      eventId: 7,
      qrToken: 'qr-token',
    );
    final stats = await api.fetchScanStats(token: 'token', eventId: 7);

    expect(ticket.eventId, 7);
    expect(scan.success, isTrue);
    expect(stats.checkInPercentage, 40);
  });

  test('QR API surfaces forbidden ticket access', () async {
    final api = QRCheckinApi(
      client: MockClient((_) async => http.Response('{}', 403)),
    );

    await expectLater(
      api.fetchMyQRCode(token: 'token', eventId: 7),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 403),
      ),
    );
  });
}
