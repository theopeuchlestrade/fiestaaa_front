import 'dart:convert';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/notifications/data/notifications_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('registerDevice posts token metadata to the device endpoint', () async {
    late http.Request capturedRequest;
    final api = NotificationsApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 201);
      }),
    );

    await api.registerDevice(
      authToken: 'session-token',
      fcmToken: 'fcm-token',
      platform: 'web',
      locale: 'fr',
      appVersion: '0.1.0',
    );

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/me/devices'));
    expect(capturedRequest.headers['Authorization'], 'Bearer session-token');
    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(body, {
      'token': 'fcm-token',
      'platform': 'web',
      'locale': 'fr',
      'app_version': '0.1.0',
    });
  });

  test('refreshDevice posts old and new tokens', () async {
    late http.Request capturedRequest;
    final api = NotificationsApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 200);
      }),
    );

    await api.refreshDevice(
      authToken: 'session-token',
      oldToken: 'old-token',
      newToken: 'new-token',
      platform: 'ios',
    );

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/me/devices/refresh'));
    expect(body['old_token'], 'old-token');
    expect(body['new_token'], 'new-token');
    expect(body['platform'], 'ios');
    expect(body.containsKey('locale'), isFalse);
    expect(body.containsKey('app_version'), isFalse);
  });

  test('deleteDevice surfaces non-success responses as ApiException', () async {
    final api = NotificationsApi(
      client: MockClient((request) async => http.Response('', 500)),
    );

    await expectLater(
      api.deleteDevice(authToken: 'session-token', fcmToken: 'fcm-token'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });
}
