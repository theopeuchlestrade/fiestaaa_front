import 'navigation_diagnostics.dart';
import 'config.dart';
import '../features/auth/data/mobile_session_manager.dart';
import 'event_data_store.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'platform_http_client_stub.dart'
    if (dart.library.io) 'platform_http_client_native.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart';

class ApiHttpClient extends http.BaseClient {
  ApiHttpClient(
    this._inner, {
    this.timeout = const Duration(seconds: 15),
    Future<String>? clientVersion,
  }) : _clientVersion = clientVersion ?? _platformClientVersion;

  final http.Client _inner;
  int _active = 0;
  bool _closed = false;
  void _release() {
    _active--;
    if (_closed && _active == 0) _inner.close();
  }

  final Duration timeout;
  final Future<String> _clientVersion;

  static final Future<String> _platformClientVersion =
      PackageInfo.fromPlatform()
          .then((info) => 'flutter/${info.version}')
          .onError((_, _) => 'flutter/unknown');

  static final StreamController<ApiUnauthorizedResponse>
  _unauthorizedController =
      StreamController<ApiUnauthorizedResponse>.broadcast();

  static Stream<ApiUnauthorizedResponse> get unauthorized =>
      _unauthorizedController.stream;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client closed');
    _active++;
    final elapsed = Stopwatch()..start();
    // Capture the request's identity before web transport strips Authorization.
    final authorization = request.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .firstOrNull;
    var bearerToken = authorization?.startsWith('Bearer ') == true
        ? authorization!.substring(7)
        : null;
    var requestGeneration = EventDataStore.instance.applies(bearerToken)
        ? EventDataStore.instance.generation
        : null;
    try {
      final clientVersion = await _clientVersion.timeout(timeout);
      request.headers.putIfAbsent(
        'X-Fiestaaa-Client-Version',
        () => clientVersion,
      );
      final api = buildApiUri('/');
      if (!kIsWeb &&
          bearerToken != null &&
          request.url.origin == api.origin &&
          request.url.path.startsWith(api.path) &&
          request.url.path != buildApiUri('/auth/logout').path) {
        try {
          bearerToken = await MobileSessionManager.instance.tokenFor(
            bearerToken,
            _inner,
          );
          request.headers['Authorization'] = 'Bearer $bearerToken';
          if (MobileSessionManager.instance.accepts(bearerToken)) {
            requestGeneration = EventDataStore.instance.generation;
          }
        } on SessionRevokedException {
          _unauthorizedController.add(
            ApiUnauthorizedResponse(
              MobileSessionManager.instance.session?.token ?? bearerToken,
            ),
          );
          rethrow;
        }
      }
      if (kIsWeb) {
        final authHeader = request.headers.keys.firstWhere(
          (key) => key.toLowerCase() == 'authorization',
          orElse: () => '',
        );
        if (authHeader.isNotEmpty) {
          request.headers.remove(authHeader);
        }
      }
      if (elapsed.elapsed >= timeout) {
        throw TimeoutException('Response deadline exceeded');
      }
      var timedOut = false;
      final pendingResponse = _inner.send(request).then((response) {
        // A late response still owns a stream that must be released.
        if (timedOut) unawaited(response.stream.listen(null).cancel());
        return response;
      });
      final response = await pendingResponse.timeout(
        timeout - elapsed.elapsed,
        onTimeout: () {
          timedOut = true;
          throw TimeoutException('Response deadline exceeded');
        },
      );
      if ((requestGeneration == null ||
              requestGeneration == EventDataStore.instance.generation) &&
          request.method != 'GET' &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        EventDataStore.instance.mutation(bearerToken, request.url);
      }
      if (response.statusCode == 401 &&
          (requestGeneration == null ||
              requestGeneration == EventDataStore.instance.generation)) {
        _unauthorizedController.add(ApiUnauthorizedResponse(bearerToken));
      }
      return http.StreamedResponse(
        _readWithinDeadline(
          response.stream,
          elapsed,
          _resourceLabel(request.url),
        ),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on TimeoutException {
      _release();
      throw const ApiTransportException(ApiTransportError.timeout);
    } on http.ClientException {
      _release();
      throw const ApiTransportException(ApiTransportError.network);
    } catch (_) {
      _release();
      rethrow;
    }
  }

  Stream<List<int>> _readWithinDeadline(
    Stream<List<int>> source,
    Stopwatch elapsed,
    String resource,
  ) {
    StreamSubscription<List<int>>? subscription;
    Timer? timer;
    var finished = false;
    late StreamController<List<int>> controller;

    void finish([Object? error, StackTrace? stack]) {
      if (finished) return;
      finished = true;
      _release();
      NavigationDiagnostics.instance.record(resource, elapsed.elapsed);
      timer?.cancel();
      if (error != null) controller.addError(error, stack);
      unawaited(controller.close());
      unawaited(subscription?.cancel());
    }

    controller = StreamController<List<int>>(
      onListen: () {
        final remaining = timeout - elapsed.elapsed;
        subscription = source.listen(
          (bytes) {
            if (!finished) controller.add(bytes);
          },
          onError: (Object error, StackTrace stack) => finish(
            error is http.ClientException
                ? const ApiTransportException(ApiTransportError.network)
                : error is TimeoutException
                ? const ApiTransportException(ApiTransportError.timeout)
                : error,
            stack,
          ),
          onDone: finish,
        );
        if (remaining <= Duration.zero) {
          finish(const ApiTransportException(ApiTransportError.timeout));
        } else {
          timer = Timer(
            remaining,
            () =>
                finish(const ApiTransportException(ApiTransportError.timeout)),
          );
        }
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        if (!finished) _release();
        finished = true;
        timer?.cancel();
        unawaited(subscription?.cancel());
      },
    );
    return controller.stream;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_active == 0) _inner.close();
  }
}

class ApiClient extends ApiHttpClient {
  ApiClient({http.Client? inner, super.timeout})
    : super(inner ?? createPlatformHttpClient());
}

const apiHttpClientFactoryKey = #fiestaaaApiHttpClientFactory;
http.Client createApiHttpClient() {
  final factory =
      Zone.current[apiHttpClientFactoryKey] as http.Client Function()?;
  return factory == null ? ApiClient() : factory();
}

String _resourceLabel(Uri uri) {
  final parts = uri.pathSegments;
  for (final name in [
    'carpools',
    'expenses',
    'polls',
    'items',
    'invitations',
    'friends',
    'auth',
    'events',
  ]) {
    if (parts.contains(name)) return 'http:$name';
  }
  return 'http:other';
}

enum ApiTransportError { timeout, network }

class ApiTransportException implements Exception {
  const ApiTransportException(this.error);

  final ApiTransportError error;
}

/// A refusal belongs to the request that failed, not every active session.
/// Keep credentials in memory only; never include them in logs or error text.
class ApiUnauthorizedResponse {
  const ApiUnauthorizedResponse(this._bearerToken);
  final String? _bearerToken;

  bool appliesToSession(String token, {required bool cookieSession}) =>
      cookieSession || (_bearerToken != null && _bearerToken == token);
}
