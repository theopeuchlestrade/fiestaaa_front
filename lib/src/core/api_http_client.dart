import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'platform_http_client_stub.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart';

class ApiHttpClient extends http.BaseClient {
  ApiHttpClient(
    this._inner, {
    this.timeout = const Duration(seconds: 15),
    Future<String>? clientVersion,
  }) : _clientVersion = clientVersion ?? _platformClientVersion;

  final http.Client _inner;
  final Duration timeout;
  final Future<String> _clientVersion;

  static final Future<String> _platformClientVersion =
      PackageInfo.fromPlatform()
          .then((info) => 'flutter/${info.version}')
          .onError((_, _) => 'flutter/unknown');

  static final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();

  static Stream<void> get unauthorized => _unauthorizedController.stream;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final elapsed = Stopwatch()..start();
    try {
      final clientVersion = await _clientVersion.timeout(timeout);
      request.headers.putIfAbsent(
        'X-Fiestaaa-Client-Version',
        () => clientVersion,
      );
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
      if (response.statusCode == 401) {
        _unauthorizedController.add(null);
      }
      return http.StreamedResponse(
        _readWithinDeadline(response.stream, elapsed),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on TimeoutException {
      throw const ApiTransportException(ApiTransportError.timeout);
    } on http.ClientException {
      throw const ApiTransportException(ApiTransportError.network);
    }
  }

  Stream<List<int>> _readWithinDeadline(
    Stream<List<int>> source,
    Stopwatch elapsed,
  ) {
    StreamSubscription<List<int>>? subscription;
    Timer? timer;
    var finished = false;
    late StreamController<List<int>> controller;

    void finish([Object? error, StackTrace? stack]) {
      if (finished) return;
      finished = true;
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
        finished = true;
        timer?.cancel();
        unawaited(subscription?.cancel());
      },
    );
    return controller.stream;
  }

  @override
  void close() {
    _inner.close();
  }
}

class ApiClient extends ApiHttpClient {
  ApiClient({http.Client? inner, super.timeout})
    : super(inner ?? createPlatformHttpClient());
}

http.Client createApiHttpClient() => ApiClient();

enum ApiTransportError { timeout, network }

class ApiTransportException implements Exception {
  const ApiTransportException(this.error);

  final ApiTransportError error;
}
