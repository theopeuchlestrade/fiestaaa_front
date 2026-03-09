import 'dart:async';
import 'dart:convert';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeClient {
  RealtimeClient({required this.token, this.eventId, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;

  final String token;
  int? eventId;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  bool _manuallyClosed = false;
  int _connectGeneration = 0;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect() {
    _manuallyClosed = false;
    unawaited(_openChannel());
  }

  void updateEvent(int? id) {
    eventId = id;
    unawaited(_reconnect());
  }

  Future<void> _openChannel() async {
    final generation = ++_connectGeneration;
    final targetEventId = eventId;

    try {
      final ticket = await _fetchTicket(targetEventId);
      if (_manuallyClosed || generation != _connectGeneration) return;

      final uri = buildWsUri(
        '/ws',
        queryParameters: {
          'ticket': ticket,
          if (targetEventId != null) 'event_id': '$targetEventId',
        },
      );

      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleData,
        onError: (_) => _reconnectSoon(),
        onDone: _reconnectSoon,
        cancelOnError: true,
      );
    } catch (_) {
      if (_manuallyClosed || generation != _connectGeneration) return;
      _reconnectSoon();
    }
  }

  Future<String> _fetchTicket(int? targetEventId) async {
    final response = await _httpClient.get(
      buildApiUri(
        '/ws-ticket',
        queryParameters: {
          if (targetEventId != null) 'event_id': '$targetEventId',
        },
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw StateError('Ticket request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid realtime ticket payload');
    }

    final ticket = decoded['ticket'];
    if (ticket is! String || ticket.isEmpty) {
      throw const FormatException('Missing realtime ticket');
    }

    return ticket;
  }

  Future<void> _closeCurrentChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _reconnectSoon() {
    if (_manuallyClosed) return;
    final generation = _connectGeneration;
    Future.delayed(const Duration(seconds: 2), () {
      if (_manuallyClosed || generation != _connectGeneration) {
        return;
      }
      unawaited(_reconnect());
    });
  }

  Future<void> _reconnect() async {
    if (_manuallyClosed) return;
    _connectGeneration++;
    await _closeCurrentChannel();
    if (_manuallyClosed) return;
    await _openChannel();
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

  Future<void> dispose() async {
    _manuallyClosed = true;
    _connectGeneration++;
    await _closeCurrentChannel();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    await _controller.close();
  }
}
