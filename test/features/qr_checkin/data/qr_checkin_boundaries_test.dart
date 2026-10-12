import 'dart:convert';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final status in [403, 409]) {
    test(
      'scan $status preserves structured refusal and member identity',
      () async {
        final api = QRCheckinApi(
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer fixture');
            expect(request.url.path, endsWith('/events/7/scan-qr'));
            expect(jsonDecode(request.body), {'token': 'ticket'});
            return http.Response(
              jsonEncode({
                'success': false,
                'status': status == 409 ? 'already_scanned' : 'expired',
                'message': 'fixture refusal',
                'user_email': 'guest@example.invalid',
                'user_handle': 'guest',
                'user_avatar_url': null,
                'scanned_at': '2030-01-01T10:00:00Z',
              }),
              status,
            );
          }),
        );
        final result = await api.scanQRCode(
          token: 'fixture',
          eventId: 7,
          qrToken: 'ticket',
        );
        expect(result.success, isFalse);
        expect(result.status, status == 409 ? 'already_scanned' : 'expired');
        expect(result.userHandle, 'guest');
        expect(result.scannedAt, DateTime.utc(2030, 1, 1, 10));
        api.dispose();
      },
    );
  }
  for (final status in [401, 403, 404, 500]) {
    test('scan $status without result fails with the HTTP status', () async {
      final api = QRCheckinApi(
        client: MockClient(
          (_) async => http.Response('{"error":"refused"}', status),
        ),
      );
      await expectLater(
        api.scanQRCode(token: 'fixture', eventId: 7, qrToken: 'ticket'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', status),
        ),
      );
      api.dispose();
    });
    test(
      'statistics $status never become successful empty statistics',
      () async {
        final api = QRCheckinApi(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(
          api.fetchScanStats(token: 'fixture', eventId: 7),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
        api.dispose();
      },
    );
  }
  test('ticket serialization preserves token, event and UTC expiry', () {
    final json = {
      'qr_token': 'ticket',
      'event_id': 7,
      'generated_at': '2030-01-01T10:00:00.000Z',
      'expires_at': '2030-01-01T10:05:00.000Z',
    };
    expect(QRCodeData.fromJson(json).toJson(), json);
    expect(
      const QRScanStats(
        totalInvited: 0,
        totalCheckedIn: 0,
        pendingCheckins: 0,
      ).checkInPercentage,
      0,
    );
  });
  for (final body in ['[]', '{', '{}']) {
    test('malformed ticket $body cannot produce a usable ticket', () async {
      final api = QRCheckinApi(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        api.fetchMyQRCode(token: 'fixture', eventId: 7),
        throwsA(anything),
      );
      api.dispose();
    });
  }
}
