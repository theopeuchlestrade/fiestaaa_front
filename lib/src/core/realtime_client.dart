import 'dart:async';
import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeClient {
  RealtimeClient({required this.token, this.eventId});

  final String token;
  int? eventId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  bool _manuallyClosed = false;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect() {
    _manuallyClosed = false;
    _openChannel();
  }

  void updateEvent(int? id) {
    eventId = id;
    _reconnect();
  }

  void _openChannel() {
    final uri = buildWsUri(
      '/ws',
      queryParameters: {
        'token': token,
        if (eventId != null) 'event_id': '$eventId',
      },
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleData,
        onError: (_) => _reconnectSoon(),
        onDone: _reconnectSoon,
        cancelOnError: true,
      );
    } catch (_) {
      _reconnectSoon();
    }
  }

  void _handleData(dynamic data) {
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          _controller.add(decoded);
        }
      } catch (_) {
        // ignore malformed payloads
      }
    }
  }

  void _reconnectSoon() {
    if (_manuallyClosed) return;
    Future.delayed(const Duration(seconds: 2), _reconnect);
  }

  void _reconnect() {
    if (_manuallyClosed) return;
    _subscription?.cancel();
    _channel?.sink.close();
    _openChannel();
  }

  Future<void> dispose() async {
    _manuallyClosed = true;
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _controller.close();
  }
}
