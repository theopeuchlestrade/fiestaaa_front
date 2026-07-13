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
    final clientVersion = await _clientVersion;
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
    try {
      final response = await _inner.send(request).timeout(timeout);
      if (response.statusCode == 401) {
        _unauthorizedController.add(null);
      }
      return response;
    } on TimeoutException {
      throw const ApiTransportException(ApiTransportError.timeout);
    } on http.ClientException {
      throw const ApiTransportException(ApiTransportError.network);
    }
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
