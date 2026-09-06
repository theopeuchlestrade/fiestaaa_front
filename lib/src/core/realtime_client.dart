import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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

enum RealtimeConnectionState {
  connecting,
  connected,
  interrupted,
  disabled,
  closed,
}

class RealtimeClient {
  RealtimeClient({
    required this.token,
    this.eventId,
    http.Client? httpClient,
    RealtimeReconnectBackoff? reconnectBackoff,
    WebSocketChannel Function(Uri)? channelFactory,
  }) : _httpClient = httpClient ?? createApiHttpClient(),
       _ownsHttpClient = httpClient == null,
       _reconnectBackoff = reconnectBackoff ?? RealtimeReconnectBackoff(),
       _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final String token;
  int? eventId;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final RealtimeReconnectBackoff _reconnectBackoff;
  final WebSocketChannel Function(Uri) _channelFactory;
  final connectionState = ValueNotifier(RealtimeConnectionState.connecting);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _readyTimer;
  final _controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  bool _disposed = false;
  int _connectGeneration = 0;

  late final Stream<Map<String, dynamic>> _publicStream = Stream.multi((sink) {
    if (_disposed) {
      sink.close();
      return;
    }
    final subscription = _controller.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.add({'type': 'realtime.status', 'state': connectionState.value.name});
    sink.onCancel = subscription.cancel;
  }, isBroadcast: true);

  Stream<Map<String, dynamic>> get stream => _publicStream;

  void _setState(RealtimeConnectionState state) {
    if (_disposed || connectionState.value == state) return;
    connectionState.value = state;
    // Local state events also reach screens that share this client's stream.
    _controller.add({'type': 'realtime.status', 'state': state.name});
  }

  void connect() {
    if (_disposed) return;
    _reconnectBackoff.reset();
    unawaited(_reconnect());
  }

  void updateEvent(int? id) {
    if (_disposed || id == eventId) return;
    eventId = id;
    unawaited(_reconnect());
  }

  Future<void> _openChannel(int generation) async {
    final targetEventId = eventId;
    try {
      final ticket = await _fetchTicket(targetEventId);
      if (_disposed || generation != _connectGeneration) return;
      final channel = _channelFactory(
        buildWsUri(
          '/ws',
          queryParameters: {
            'ticket': ticket,
            if (targetEventId != null) 'event_id': '$targetEventId',
          },
        ),
      );
      _channel = channel;
      _readyTimer = Timer(const Duration(seconds: 20), () {
        if (generation == _connectGeneration) _reconnectSoon();
      });
      _subscription = channel.stream.listen(
        (data) {
          if (!_disposed && generation == _connectGeneration) _handleData(data);
        },
        onError: (_) {
          if (generation == _connectGeneration) _reconnectSoon();
        },
        onDone: () {
          if (generation == _connectGeneration) _reconnectSoon();
        },
        cancelOnError: true,
      );
      await channel.ready;
    } catch (_) {
      if (_disposed || generation != _connectGeneration) return;
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

  void _closeCurrentChannel() {
    // Detach first so an old close cannot clear a newer connection.
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _readyTimer?.cancel();
    _readyTimer = null;
    unawaited(subscription?.cancel());
    // Waiting for a peer's close handshake must not block recovery/disposal.
    if (channel != null) {
      unawaited(channel.sink.close().catchError((Object _) {}));
    }
  }

  void _reconnectSoon() {
    if (_disposed || _reconnectTimer?.isActive == true) return;
    _setState(RealtimeConnectionState.interrupted);
    final generation = ++_connectGeneration;
    _closeCurrentChannel();
    _reconnectTimer = Timer(_reconnectBackoff.nextDelay(), () {
      _reconnectTimer = null;
      if (_disposed || generation != _connectGeneration) return;
      unawaited(_openChannel(generation));
    });
  }

  Future<void> _reconnect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final generation = ++_connectGeneration;
    _closeCurrentChannel();
    _setState(RealtimeConnectionState.connecting);
    await _openChannel(generation);
  }

  void _handleData(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      message = decoded;
    } catch (_) {
      return;
    }
    if (message['type'] == 'realtime.ready') {
      _readyTimer?.cancel();
      _reconnectBackoff.reset();
      _setState(RealtimeConnectionState.connected);
    } else if (message['type'] == 'warning' &&
        message['payload'] is Map &&
        message['payload']['message'] == 'realtime_disabled') {
      _readyTimer?.cancel();
      _setState(RealtimeConnectionState.disabled);
    }
    _controller.add(message);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _setState(RealtimeConnectionState.closed);
    _disposed = true;
    _connectGeneration++;
    _reconnectTimer?.cancel();
    _closeCurrentChannel();
    if (_ownsHttpClient) _httpClient.close();
    connectionState.dispose();
    await _controller.close();
  }
}
