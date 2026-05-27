import 'dart:convert';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loginWithProvider posts Apple id token to oauth endpoint', () async {
    late http.Request capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'token': 'session-token',
            'public_id': 'public-user-id',
            'email': 'apple.user@example.com',
            'handle': 'apple_user',
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final session = await api.loginWithProvider(
      provider: 'apple',
      idToken: 'apple-id-token',
      email: ' Apple.User@Example.com ',
      displayName: ' Apple User ',
    );

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/oauth/apple'));
    expect(body['idToken'], 'apple-id-token');
    expect(body['accessToken'], isNull);
    expect(body['email'], 'Apple.User@Example.com');
    expect(body['name'], 'Apple User');
    expect(session.token, 'session-token');
    expect(session.email, 'apple.user@example.com');
    expect(session.handle, 'apple_user');
  });

  test(
    'loginWithProvider posts Google access token to oauth endpoint',
    () async {
      late http.Request capturedRequest;
      final api = AuthApi(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'token': 'google-session-token',
              'public_id': 'google-public-id',
              'email': 'google.user@example.com',
              'handle': 'google_user',
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      );

      await api.loginWithProvider(
        provider: 'google',
        accessToken: 'google-access-token',
      );

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, endsWith('/auth/oauth/google'));
      expect(body['idToken'], isNull);
      expect(body['accessToken'], 'google-access-token');
    },
  );

  test(
    'loginWithProvider rejects empty provider tokens before posting',
    () async {
      final api = AuthApi(
        client: MockClient((request) async {
          fail('loginWithProvider should not send a request without a token');
        }),
      );

      await expectLater(
        api.loginWithProvider(provider: 'apple', idToken: '   '),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('logout sends bearer authorization when a token is provided', () async {
    late http.BaseRequest capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 200);
      }),
    );

    await api.logout(token: 'native-session-token');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/logout'));
    expect(
      capturedRequest.headers['Authorization'],
      'Bearer native-session-token',
    );
  });

  test('logout omits authorization when no token is provided', () async {
    late http.BaseRequest capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 200);
      }),
    );

    await api.logout();

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/logout'));
    expect(capturedRequest.headers.containsKey('Authorization'), isFalse);
  });
}
