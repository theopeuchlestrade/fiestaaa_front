import 'dart:async';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _StreamClient extends http.BaseClient {
  _StreamClient(this.respond);
  final Future<http.StreamedResponse> Function() respond;
  bool closed = false;
  int calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    return respond();
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  test('adds the client version header', () async {
    late http.Request captured;
    final client = ApiHttpClient(
      MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
      clientVersion: Future.value('flutter/0.2.0'),
    );

    await client.get(Uri.parse('https://example.test/me'));
    expect(captured.headers['X-Fiestaaa-Client-Version'], 'flutter/0.2.0');
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

  test(
    'cancels a stalled body without closing the shared client or retrying',
    () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final inner = _StreamClient(
        () async => http.StreamedResponse(body.stream, 200),
      );
      final client = ApiHttpClient(
        inner,
        timeout: const Duration(milliseconds: 50),
        clientVersion: Future.value('test'),
      );
      await expectLater(
        client.post(Uri.parse('https://example.test/vote')),
        throwsA(
          isA<ApiTransportException>().having(
            (e) => e.error,
            'error',
            ApiTransportError.timeout,
          ),
        ),
      );
      expect(cancelled, isTrue);
      expect(inner.closed, isFalse);
      expect(inner.calls, 1);
      client.close();
    },
  );

  test('body fragments do not reset the total deadline', () async {
    var cancelled = false;
    Timer? ticker;
    final body = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
        ticker?.cancel();
      },
    );
    final inner = _StreamClient(() async {
      ticker = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => body.add([65]),
      );
      return http.StreamedResponse(body.stream, 200);
    });
    final client = ApiHttpClient(
      inner,
      timeout: const Duration(milliseconds: 80),
      clientVersion: Future.value('test'),
    );
    await expectLater(
      client.get(Uri.parse('https://example.test/events')),
      throwsA(
        isA<ApiTransportException>().having(
          (e) => e.error,
          'error',
          ApiTransportError.timeout,
        ),
      ),
    );
    expect(cancelled, isTrue);
    client.close();
  });

  test(
    'maps errors during body reading and preserves normal response metadata',
    () async {
      final inner = _StreamClient(
        () async => http.StreamedResponse(
          Stream.error(http.ClientException('connection lost')),
          200,
        ),
      );
      final client = ApiHttpClient(inner, clientVersion: Future.value('test'));
      await expectLater(
        client.get(Uri.parse('https://example.test/events')),
        throwsA(
          isA<ApiTransportException>().having(
            (e) => e.error,
            'error',
            ApiTransportError.network,
          ),
        ),
      );
      client.close();

      final normal = ApiHttpClient(
        _StreamClient(
          () async => http.StreamedResponse(
            Stream.fromIterable([
              [65],
              [66],
            ]),
            201,
            headers: {'x-test': 'value'},
            contentLength: 2,
            reasonPhrase: 'Created',
          ),
        ),
        clientVersion: Future.value('test'),
      );
      final response = await normal.get(
        Uri.parse('https://example.test/events'),
      );
      expect(response.body, 'AB');
      expect(response.statusCode, 201);
      expect(response.headers['x-test'], 'value');
      expect(response.contentLength, 2);
      expect(response.reasonPhrase, 'Created');
      normal.close();
    },
  );

  test('releases responses whose headers arrive after the deadline', () async {
    final pending = Completer<http.StreamedResponse>();
    var cancelled = false;
    final body = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final client = ApiHttpClient(
      _StreamClient(() => pending.future),
      timeout: const Duration(milliseconds: 10),
      clientVersion: Future.value('test'),
    );
    await expectLater(
      client.get(Uri.parse('https://example.test/events')),
      throwsA(isA<ApiTransportException>()),
    );
    pending.complete(http.StreamedResponse(body.stream, 200));
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    client.close();
  });

  test(
    'time spent waiting for headers is deducted from the body budget',
    () async {
      Timer? completeBody;
      final body = StreamController<List<int>>(
        onCancel: () {
          completeBody?.cancel();
        },
      );
      final client = ApiHttpClient(
        _StreamClient(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          completeBody = Timer(const Duration(milliseconds: 50), () {
            body.add([65]);
            unawaited(body.close());
          });
          return http.StreamedResponse(body.stream, 200);
        }),
        timeout: const Duration(milliseconds: 80),
        clientVersion: Future.value('test'),
      );
      await expectLater(
        client.get(Uri.parse('https://example.test/events')),
        throwsA(
          isA<ApiTransportException>().having(
            (e) => e.error,
            'error',
            ApiTransportError.timeout,
          ),
        ),
      );
      client.close();
    },
  );

  test('metadata lookup cannot leave a request waiting forever', () async {
    final inner = _StreamClient(
      () async => http.StreamedResponse(const Stream.empty(), 200),
    );
    final client = ApiHttpClient(
      inner,
      clientVersion: Completer<String>().future,
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      client.get(Uri.parse('https://example.test/events')),
      throwsA(
        isA<ApiTransportException>().having(
          (e) => e.error,
          'error',
          ApiTransportError.timeout,
        ),
      ),
    );
    expect(inner.calls, 0);
    client.close();
  });
}
