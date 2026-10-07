import 'dart:io';

import 'package:flutter/painting.dart';

import 'native_http_image.dart';

ImageProvider<Object> platformNetworkImage(String url) {
  if (Platform.isIOS || Platform.isAndroid) return NativeHttpImage(url);
  return NetworkImage(url);
}
