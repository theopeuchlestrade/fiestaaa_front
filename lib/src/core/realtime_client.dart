import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

const _initialReconnectDelay = Duration(seconds: 2);
const _maxReconnectDelay = Duration(seconds: 30);
const _maxReconnectAttempt = 4;
const _reconnectJitterRatio = 0.2;

class RealtimeReconnectBackoff {
  RealtimeReconnectBackoff({
    Random? random,
    double jitterRatio = _reconnectJitterRatio,
  }) : assert(jitterRatio >= 0 && jitterRatio <= 1),
       _random = random ?? Random(),
       _jitterRatio = jitterRatio;

  final Random _random;
  final double _jitterRatio;
  int _attempt = 0;

  Duration nextDelay() {
    final baseDelay = _baseDelayForAttempt(_attempt);
    if (_attempt < _maxReconnectAttempt) {
      _attempt += 1;
    }

    final jitterWindow = (baseDelay.inMilliseconds * _jitterRatio).round();
    if (jitterWindow == 0) {
      return baseDelay;
    }

    final jitter = _random.nextInt(jitterWindow * 2 + 1) - jitterWindow;
    final milliseconds = max(
      0,
      min(baseDelay.inMilliseconds + jitter, _maxReconnectDelay.inMilliseconds),
    );
    return Duration(milliseconds: milliseconds);
  }

  void reset() {
    _attempt = 0;
  }

  Duration _baseDelayForAttempt(int attempt) {
    var milliseconds = _initialReconnectDelay.inMilliseconds;
    for (var i = 0; i < attempt; i += 1) {
      milliseconds = min(milliseconds * 2, _maxReconnectDelay.inMilliseconds);
    }
    return Duration(milliseconds: milliseconds);
  }
}

class RealtimeClient {
  RealtimeClient({
    required this.token,
    this.eventId,
    http.Client? httpClient,
    RealtimeReconnectBackoff? reconnectBackoff,
  }) : _httpClient = httpClient ?? createApiHttpClient(),
       _ownsHttpClient = httpClient == null,
       _reconnectBackoff = reconnectBackoff ?? RealtimeReconnectBackoff();

  final String token;
  int? eventId;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final RealtimeReconnectBackoff _reconnectBackoff;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  final _controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  bool _manuallyClosed = false;
  int _connectGeneration = 0;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect() {
    _manuallyClosed = false;
    _cancelReconnectTimer();
    _reconnectBackoff.reset();
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
    if (_manuallyClosed || _reconnectTimer?.isActive == true) return;
    final generation = _connectGeneration;
    final delay = _reconnectBackoff.nextDelay();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_manuallyClosed || generation != _connectGeneration) {
        return;
      }
      unawaited(_reconnect());
    });
  }

  Future<void> _reconnect() async {
    if (_manuallyClosed) return;
    _cancelReconnectTimer();
    _connectGeneration++;
    await _closeCurrentChannel();
    if (_manuallyClosed) return;
    await _openChannel();
  }

  void _handleData(dynamic data) {
    _reconnectBackoff.reset();
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
    _cancelReconnectTimer();
    await _closeCurrentChannel();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    await _controller.close();
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}
