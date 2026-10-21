import 'package:fiestaaa_front/src/core/event_data_store.dart';

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

  test(
    'late 401 belongs to old bearer, never a newly authenticated session',
    () async {
      final pending = Completer<http.Response>();
      final client = ApiHttpClient(
        MockClient((_) => pending.future),
        clientVersion: Future.value('test'),
      );
      final notice = ApiHttpClient.unauthorized.first;
      final request = client.get(
        Uri.parse('https://example.test/ws-ticket'),
        headers: {'Authorization': 'Bearer old-session'},
      );
      await Future<void>.delayed(Duration.zero);
      pending.complete(http.Response('{}', 401));
      await request;
      final failure = await notice;
      expect(
        failure.appliesToSession('new-session', cookieSession: false),
        isFalse,
      );
      expect(
        failure.appliesToSession('old-session', cookieSession: false),
        isTrue,
      );
      client.close();
    },
  );
  test(
    'failed public login cannot invalidate an active native bearer',
    () async {
      final client = ApiHttpClient(
        MockClient((_) async => http.Response('{}', 401)),
        clientVersion: Future.value('test'),
      );
      final notice = ApiHttpClient.unauthorized.first;
      await client.post(Uri.parse('https://example.test/auth/login'));
      expect(
        (await notice).appliesToSession('active-session', cookieSession: false),
        isFalse,
      );
      client.close();
    },
  );
  test('cookie refusals retain existing web session invalidation', () {
    expect(
      const ApiUnauthorizedResponse(null)
          .appliesToSession('', cookieSession: true),
      isTrue,
    );
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
  test(
    'closing a client retains an in-flight response for shared readers',
    () async {
      final pending = Completer<http.Response>();
      final client = ApiHttpClient(
        MockClient((_) => pending.future),
        clientVersion: Future.value('test'),
      );
      final response = client.get(
        Uri.parse('https://fixture.invalid/events/1'),
      );
      await Future<void>.delayed(Duration.zero);
      client.close();
      pending.complete(http.Response('shared', 200));
      expect((await response).body, 'shared');
    },
  );
  test(
    'late unauthorized response does not clear a replacement session',
    () async {
      final store = EventDataStore.instance..bind('old-token', 'old-account');
      final pending = Completer<http.Response>();
      final events = <ApiUnauthorizedResponse>[];
      final subscription = ApiHttpClient.unauthorized.listen(events.add);
      final client = ApiHttpClient(
        MockClient((_) => pending.future),
        clientVersion: Future.value('test'),
      );
      final response = client.get(
        Uri.parse('https://fixture.invalid/events/1'),
        headers: {'Authorization': 'Bearer old-token'},
      );
      await Future<void>.delayed(Duration.zero);
      store.bind('new-token', 'new-account');
      pending.complete(http.Response('{}', 401));
      await response;
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await subscription.cancel();
      client.close();
      store.clear();
    },
  );
}
