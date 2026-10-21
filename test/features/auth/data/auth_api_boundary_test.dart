import 'dart:convert';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'registration and verification preserve generic status and exact token',
    () async {
      final requests = <http.Request>[];
      final api = AuthApi(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            '{}',
            r.url.path.endsWith('register') ? 201 : 200,
          );
        }),
      );
      expect(
        await api.register(email: 'qa@example.invalid'),
        'verification_pending',
      );
      expect(await api.verifyEmail('single-use'), 'verified');
      expect(jsonDecode(requests.first.body), {'email': 'qa@example.invalid'});
      expect(jsonDecode(requests.last.body), {'token': 'single-use'});
      expect(requests.every((r) => r.method == 'POST'), isTrue);
      api.dispose();
    },
  );
  test(
    'complete registration trims handle and uses native bearer response',
    () async {
      late http.Request captured;
      final api = AuthApi(
        client: MockClient((r) async {
          captured = r;
          return http.Response(
            jsonEncode({
              'token': 'fixture',
              'email': 'qa@example.invalid',
              'handle': 'qauser',
              'public_id': 'qa-id',
            }),
            200,
          );
        }),
      );
      final session = await api.completeRegistration(
        token: 'completion',
        password: 'FixturePassword1!',
        handle: '  qauser  ',
      );
      expect(jsonDecode(captured.body), {
        'token': 'completion',
        'password': 'FixturePassword1!',
        'handle': 'qauser',
      });
      expect(captured.headers['X-Fiestaaa-Auth-Response'], 'bearer-refresh');
      expect(session.publicId, 'qa-id');
      await api.completeRegistration(
        token: 'completion',
        password: 'FixturePassword1!',
        handle: ' ',
      );
      expect((jsonDecode(captured.body) as Map).containsKey('handle'), isFalse);
      api.dispose();
    },
  );
  for (final operation in [
    'register',
    'verify',
    'complete',
    'login',
    'oauth',
    'validate',
  ]) {
    test(
      '$operation retains refusal status and machine-readable code',
      () async {
        final api = AuthApi(
          client: MockClient(
            (_) async => http.Response('{"error":"rate_limited"}', 429),
          ),
        );
        Future<Object?> invoke() => switch (operation) {
          'register' => api.register(email: 'qa@example.invalid'),
          'verify' => api.verifyEmail('used'),
          'complete' => api.completeRegistration(
            token: 'used',
            password: 'FixturePassword1!',
          ),
          'login' => api.login(identifier: 'qauser', password: 'wrong'),
          'oauth' => api.loginWithProvider(
            provider: 'google',
            idToken: 'fixture-token',
          ),
          _ => api.validateSession('fixture'),
        };
        await expectLater(
          invoke(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'HTTP status', 429)
                .having((e) => e.code, 'code', 'rate_limited'),
          ),
        );
        api.dispose();
      },
    );
  }
  test(
    'provider request omits blank identity fields and carries Apple code/Android origin',
    () async {
      late http.Request captured;
      final api = AuthApi(
        client: MockClient((r) async {
          captured = r;
          return http.Response(
            '{"token":"fixture","email":"qa@example.invalid"}',
            200,
          );
        }),
      );
      await api.loginWithProvider(
        provider: 'apple',
        idToken: ' token ',
        accessToken: ' ',
        authorizationCode: 'one-use-code',
        android: true,
        email: ' ',
        displayName: ' ',
      );
      expect(jsonDecode(captured.body), {
        'idToken': 'token',
        'authorizationCode': 'one-use-code',
        'android': true,
      });
      await expectLater(
        api.loginWithProvider(
          provider: 'google',
          idToken: ' ',
          accessToken: ' ',
        ),
        throwsA(isA<ApiException>()),
      );
      api.dispose();
    },
  );
  for (final body in [
    '{"email":"qa@example.invalid"}',
    '{"token":"","email":"qa@example.invalid"}',
    '[]',
    'not-json',
  ]) {
    test(
      'invalid successful login body $body is never accepted as a session',
      () async {
        final api = AuthApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          api.login(identifier: 'qauser', password: 'fixture'),
          throwsA(isA<ApiException>()),
        );
        api.dispose();
      },
    );
  }
  test(
    'email fallback is available only when a nonempty native token exists',
    () async {
      final api = AuthApi(
        client: MockClient(
          (_) async => http.Response('{"token":"fixture"}', 200),
        ),
      );
      final session = await api.login(
        identifier: 'qa@example.invalid',
        password: 'fixture',
      );
      expect(session.email, 'qa@example.invalid');
      expect(session.token, 'fixture');
      api.dispose();
    },
  );
  test(
    'validation distinguishes missing identity, unauthorized and unavailable',
    () async {
      var status = 200;
      var body = '{}';
      late http.Request captured;
      final api = AuthApi(
        client: MockClient((r) async {
          captured = r;
          return http.Response(body, status);
        }),
      );
      expect(await api.validateSession(''), isNull);
      expect(captured.headers.containsKey('Authorization'), isFalse);
      body =
          '{"email":"qa@example.invalid","public_id":"qa-id","handle":"qauser"}';
      expect((await api.validateSession('fixture'))?.handle, 'qauser');
      expect(captured.headers['Authorization'], 'Bearer fixture');
      status = 401;
      expect(await api.validateSession('fixture'), isNull);
      status = 503;
      body = 'gateway unavailable';
      await expectLater(
        api.validateSession('fixture'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      api.dispose();
    },
  );
  test(
    'logout sends the active token, and no authorization for absent token',
    () async {
      final requests = <http.Request>[];
      final api = AuthApi(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('', 204);
        }),
      );
      await api.logout(token: 'fixture');
      await api.logout();
      expect(requests.first.url.path, '/auth/logout');
      expect(requests.first.headers['Authorization'], 'Bearer fixture');
      expect(requests.last.headers.containsKey('Authorization'), isFalse);
      api.dispose();
    },
  );
}
