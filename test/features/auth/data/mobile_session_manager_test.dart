import 'dart:async';
import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/mobile_session_manager.dart';
import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage implements SessionStorageBackend {
  final values = <String, String>{};
  @override
  Future<void> write({required String key, String? value}) async {
    values[key] = value!;
  }

  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

String jwt(int seconds) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + seconds})))}.signature';

SessionData session(String token, {String? refresh = 'refresh-old'}) =>
    SessionData(
      token: token,
      email: 'test@example.invalid',
      publicId: 'user-id',
      refreshToken: refresh,
    );

void main() {
  final manager = MobileSessionManager.instance;
  setUp(() async {
    await manager.clear();
    SessionStorage.debugSetStorageBackend(_Storage());
  });
  tearDown(() async {
    await manager.clear();
    SessionStorage.debugResetStorageBackend();
  });

  test(
    'a session survives 48 hours and simultaneous requests rotate only once',
    () async {
      final old = jwt(-48 * 3600);
      final next = jwt(3600);
      manager.bind(session(old));
      final response = Completer<http.Response>();
      var renewals = 0;
      final requests = <http.Request>[];
      final client = ApiHttpClient(
        MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            renewals++;
            expect(jsonDecode(request.body)['refresh_token'], 'refresh-old');
            return response.future;
          }
          expect((await SessionStorage.load())!.refreshToken, 'refresh-new');
          requests.add(request);
          return http.Response('{}', 200);
        }),
        clientVersion: Future.value('test'),
      );
      final calls = List.generate(
        5,
        (_) => client.post(
          buildApiUri('/events'),
          headers: {'Authorization': 'Bearer $old'},
          body: '{"name":"event"}',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(renewals, 1);
      expect(requests, isEmpty);
      response.complete(
        http.Response(
          jsonEncode({'token': next, 'refresh_token': 'refresh-new'}),
          200,
        ),
      );
      await Future.wait(calls);
      expect(requests, hasLength(5));
      expect(
        requests.every((r) => r.headers['Authorization'] == 'Bearer $next'),
        isTrue,
      );
      expect(requests.every((r) => r.body == '{"name":"event"}'), isTrue);
      // Existing pages may still carry the token captured before renewal.
      await client.get(
        buildApiUri('/me'),
        headers: {'Authorization': 'Bearer $old'},
      );
      expect(renewals, 1);
      expect((await SessionStorage.load())!.token, next);
      client.close();
    },
  );

  test(
    'multipart uploads renew before finalization and are sent once',
    () async {
      final old = jwt(-86400);
      final next = jwt(3600);
      manager.bind(session(old));
      var uploads = 0;
      final client = ApiHttpClient(
        MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            return http.Response(
              jsonEncode({'token': next, 'refresh_token': 'new'}),
              200,
            );
          }
          uploads++;
          expect(request.headers['Authorization'], 'Bearer $next');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          expect(request.body, contains('avatar-content'));
          return http.Response('{}', 200);
        }),
        clientVersion: Future.value('test'),
      );
      final request = http.MultipartRequest('POST', buildApiUri('/me/avatar'))
        ..headers['Authorization'] = 'Bearer $old'
        ..files.add(
          http.MultipartFile.fromString(
            'file',
            'avatar-content',
            filename: 'avatar.png',
          ),
        );
      await http.Response.fromStream(await client.send(request));
      expect(uploads, 1);
      client.close();
    },
  );

  test('fresh access does not trigger renewal', () async {
    final token = jwt(3600);
    manager.bind(session(token));
    final client = MockClient((_) async => fail('Unexpected renewal'));
    expect(await manager.tokenFor(token, client), token);
  });

  for (final status in [503, 429]) {
    test(
      'temporary $status keeps credentials and retries on the next call',
      () async {
        final old = session(jwt(-86400));
        manager.bind(old);
        await SessionStorage.save(old);
        var attempts = 0;
        final client = MockClient((_) async {
          attempts++;
          return attempts == 1
              ? http.Response('{}', status)
              : http.Response(
                  jsonEncode({'token': jwt(3600), 'refresh_token': 'new'}),
                  200,
                );
        });
        await expectLater(
          manager.tokenFor(old.token, client),
          throwsA(isA<ApiException>()),
        );
        expect((await SessionStorage.load())!.refreshToken, 'refresh-old');
        expect(manager.session!.token, old.token);
        await manager.tokenFor(old.token, client);
        expect(attempts, 2);
      },
    );
  }

  test('network failure preserves the saved session', () async {
    final old = session(jwt(-86400));
    manager.bind(old);
    await SessionStorage.save(old);
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    await expectLater(
      manager.tokenFor(old.token, client),
      throwsA(isA<http.ClientException>()),
    );
    expect((await SessionStorage.load())!.refreshToken, 'refresh-old');
  });

  test(
    'revoked refresh emits unauthorized without sending the protected request',
    () async {
      final old = jwt(-86400);
      manager.bind(session(old));
      var calls = 0;
      final client = ApiHttpClient(
        MockClient((request) async {
          calls++;
          expect(request.url.path, '/auth/refresh');
          return http.Response('{}', 401);
        }),
        clientVersion: Future.value('test'),
      );
      final signal = ApiHttpClient.unauthorized.first;
      await expectLater(
        client.get(
          buildApiUri('/me'),
          headers: {'Authorization': 'Bearer $old'},
        ),
        throwsA(isA<SessionRevokedException>()),
      );
      expect(
        (await signal).appliesToSession(old, cookieSession: false),
        isTrue,
      );
      expect(calls, 1);
      client.close();
    },
  );

  test(
    'valid legacy JWT upgrades transparently with bearer authorization',
    () async {
      final old = jwt(7200);
      manager.bind(session(old, refresh: null));
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer $old');
        expect(jsonDecode(request.body)['refresh_token'], isNull);
        return http.Response(
          jsonEncode({'token': jwt(3600), 'refresh_token': 'upgraded'}),
          200,
        );
      });
      await manager.tokenFor(old, client);
      expect((await SessionStorage.load())!.refreshToken, 'upgraded');
    },
  );

  test(
    'logout during renewal discards the response and cannot restore the session',
    () async {
      final old = jwt(-3600);
      manager.bind(session(old));
      final response = Completer<http.Response>();
      final client = MockClient((_) => response.future);
      final pending = manager.tokenFor(old, client);
      final expectation = expectLater(
        pending,
        throwsA(isA<SessionChangedException>()),
      );
      final clearing = manager.clear();
      response.complete(
        http.Response(
          jsonEncode({'token': jwt(3600), 'refresh_token': 'late'}),
          200,
        ),
      );
      await clearing;
      await expectation;
      expect(manager.session, isNull);
      expect(await SessionStorage.load(), isNull);
    },
  );

  test('credentials are never substituted for a different server', () async {
    final old = jwt(-86400);
    manager.bind(session(old));
    var calls = 0;
    final client = ApiHttpClient(
      MockClient((request) async {
        calls++;
        expect(request.url.host, 'unrelated.invalid');
        expect(request.headers['Authorization'], 'Bearer $old');
        return http.Response('{}', 200);
      }),
      clientVersion: Future.value('test'),
    );
    await client.get(
      Uri.parse('https://unrelated.invalid/me'),
      headers: {'Authorization': 'Bearer $old'},
    );
    expect(calls, 1);
    client.close();
  });
}
