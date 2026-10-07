import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:ok_http/ok_http.dart';

import 'borrowed_http_client.dart';

// Keep one bounded OkHttp connection pool for the application process. The
// pinned adapter's close() evicts TLS sockets synchronously through JNI, which
// can throw NetworkOnMainThreadException on Android. API/image handles close
// independently; OkHttp expires idle connections and Android reclaims the pool
// when the process exits. Request authorization remains on individual requests.
final http.Client _androidTransport = OkHttpClient();

http.Client createPlatformHttpClient() {
  if (Platform.isIOS) {
    return CupertinoClient.fromSessionConfiguration(
      URLSessionConfiguration.ephemeralSessionConfiguration(),
    );
  }
  if (Platform.isAndroid) return BorrowedHttpClient(_androidTransport);
  return http.Client();
}
