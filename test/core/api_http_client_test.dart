import 'dart:async';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('adds the client version header', () async {
    late http.Request captured;
    final client = ApiHttpClient(
      MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
    );

    await client.get(Uri.parse('https://example.test/me'));
    expect(captured.headers['X-Fiestaaa-Client-Version'], 'flutter/0.1.2');
  });

  test('emits a global unauthorized signal', () async {
    final client = ApiHttpClient(
      MockClient((_) async => http.Response('{}', 401)),
    );
    final unauthorized = ApiHttpClient.unauthorized.first;

    await client.get(Uri.parse('https://example.test/me'));
    await expectLater(unauthorized, completes);
  });

  test('turns timeouts into a typed transport error', () async {
    final client = ApiHttpClient(
      MockClient((_) async {
        await Completer<void>().future;
        return http.Response('{}', 200);
      }),
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/me')),
      throwsA(
        isA<ApiTransportException>().having(
          (error) => error.error,
          'error',
          ApiTransportError.timeout,
        ),
      ),
    );
  });
}
