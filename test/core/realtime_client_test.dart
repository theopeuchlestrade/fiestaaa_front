import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:math';

import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Channel implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  bool closed = false;
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  Future<void> get ready async {}
  @override
  late final WebSocketSink sink = _Sink(() {
    closed = true;
    unawaited(incoming.close());
  });
  void emit(Map<String, dynamic> value) => incoming.add(jsonEncode(value));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  _Sink(this.onClose);
  final void Function() onClose;
  @override
  Future<void> close([int? code, String? reason]) async {
    onClose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RealtimeReconnectBackoff', () {
    test('backs off exponentially up to the reconnect cap', () {
      final backoff = RealtimeReconnectBackoff(jitterRatio: 0);

      expect(backoff.nextDelay(), const Duration(seconds: 2));
      expect(backoff.nextDelay(), const Duration(seconds: 4));
      expect(backoff.nextDelay(), const Duration(seconds: 8));
      expect(backoff.nextDelay(), const Duration(seconds: 16));
      expect(backoff.nextDelay(), const Duration(seconds: 30));
      expect(backoff.nextDelay(), const Duration(seconds: 30));
    });

    test('reset restarts the backoff window', () {
      final backoff = RealtimeReconnectBackoff(jitterRatio: 0);

      expect(backoff.nextDelay(), const Duration(seconds: 2));
      expect(backoff.nextDelay(), const Duration(seconds: 4));

      backoff.reset();

      expect(backoff.nextDelay(), const Duration(seconds: 2));
    });

    test('jitter stays within the configured delay bounds', () {
      final backoff = RealtimeReconnectBackoff(random: Random(1));

      final firstDelay = backoff.nextDelay();

      expect(
        firstDelay,
        greaterThanOrEqualTo(const Duration(milliseconds: 1600)),
      );
      expect(firstDelay, lessThanOrEqualTo(const Duration(milliseconds: 2400)));

      for (var i = 0; i < 10; i += 1) {
        expect(
          backoff.nextDelay(),
          lessThanOrEqualTo(const Duration(seconds: 30)),
        );
      }
    });
  });

  testWidgets(
    'ready drives resynchronization after interruption and disposal stops reconnecting',
    (tester) async {
      final channels = <_Channel>[];
      final client = RealtimeClient(
        token: 'token',
        httpClient: MockClient(
          (_) async => http.Response('{"ticket":"test"}', 200),
        ),
        reconnectBackoff: RealtimeReconnectBackoff(jitterRatio: 0),
        channelFactory: (_) {
          final channel = _Channel();
          channels.add(channel);
          return channel;
        },
      );
      var resyncs = 0;
      final subscription = client.stream.listen((message) {
        if (message['type'] == 'realtime.ready') resyncs++;
      });
      client.connect();
      await tester.pump();
      expect(client.connectionState.value, RealtimeConnectionState.connecting);
      channels.single.emit({'type': 'realtime.ready'});
      await tester.pump();
      expect(client.connectionState.value, RealtimeConnectionState.connected);
      expect(resyncs, 1);
      channels.single.incoming.addError(StateError('network lost'));
      await tester.pump();
      expect(client.connectionState.value, RealtimeConnectionState.interrupted);
      expect(channels.first.closed, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(channels.length, 2);
      channels.last.emit({'type': 'realtime.ready'});
      await tester.pump();
      expect(resyncs, 2);
      expect(client.connectionState.value, RealtimeConnectionState.connected);
      unawaited(subscription.cancel());
      await tester.pump();
      unawaited(client.dispose());
      await tester.pump();
      await tester.pump(const Duration(seconds: 40));
      expect(channels.length, 2);
      expect(channels.every((channel) => channel.closed), isTrue);
    },
  );

  testWidgets(
    'a late ticket cannot reconnect an obsolete event or disposed client',
    (tester) async {
      final pending = <Completer<http.Response>>[];
      final opened = <Uri>[];
      final client = RealtimeClient(
        token: 'token',
        eventId: 1,
        httpClient: MockClient((_) {
          final result = Completer<http.Response>();
          pending.add(result);
          return result.future;
        }),
        channelFactory: (uri) {
          opened.add(uri);
          return _Channel();
        },
      );
      client.connect();
      await tester.pump();
      client.updateEvent(2);
      await tester.pump();
      pending.first.complete(http.Response('{"ticket":"old"}', 200));
      await tester.pump();
      expect(opened, isEmpty);
      unawaited(client.dispose());
      await tester.pump();
      pending.last.complete(http.Response('{"ticket":"new"}', 200));
      await tester.pump();
      expect(opened, isEmpty);
    },
  );

  testWidgets(
    'disabled is visible to late subscribers and missing readiness triggers recovery',
    (tester) async {
      final channels = <_Channel>[];
      final client = RealtimeClient(
        token: 'token',
        httpClient: MockClient(
          (_) async => http.Response('{"ticket":"test"}', 200),
        ),
        reconnectBackoff: RealtimeReconnectBackoff(jitterRatio: 0),
        channelFactory: (_) {
          final channel = _Channel();
          channels.add(channel);
          return channel;
        },
      );
      client.connect();
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(client.connectionState.value, RealtimeConnectionState.interrupted);
      await tester.pump(const Duration(seconds: 2));
      channels.last.emit({
        'type': 'warning',
        'payload': {'message': 'realtime_disabled'},
      });
      await tester.pump();
      expect(client.connectionState.value, RealtimeConnectionState.disabled);
      final messages = <Map<String, dynamic>>[];
      final subscription = client.stream.listen(messages.add);
      await tester.pump();
      expect(messages.first['state'], 'disabled');
      await tester.pump(const Duration(seconds: 40));
      expect(channels.length, 2);
      unawaited(subscription.cancel());
      await tester.pump();
      unawaited(client.dispose());
      await tester.pump();
    },
  );
}
