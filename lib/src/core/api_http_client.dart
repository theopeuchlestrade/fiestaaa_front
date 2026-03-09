import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'platform_http_client_stub.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart';

class ApiHttpClient extends http.BaseClient {
  ApiHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (kIsWeb) {
      final authHeader = request.headers.keys.firstWhere(
        (key) => key.toLowerCase() == 'authorization',
        orElse: () => '',
      );
      if (authHeader.isNotEmpty) {
        request.headers.remove(authHeader);
      }
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

http.Client createApiHttpClient() => ApiHttpClient(createPlatformHttpClient());
