import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:ok_http/ok_http.dart';

http.Client createPlatformHttpClient() {
  if (Platform.isIOS) {
    return CupertinoClient.fromSessionConfiguration(
      URLSessionConfiguration.ephemeralSessionConfiguration(),
    );
  }
  if (Platform.isAndroid) return OkHttpClient();
  return http.Client();
}
