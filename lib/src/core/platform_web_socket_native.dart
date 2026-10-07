import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:ok_http/ok_http.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createPlatformWebSocket(Uri uri) {
  if (Platform.isIOS) {
    return AdapterWebSocketChannel(CupertinoWebSocket.connect(uri));
  }
  if (Platform.isAndroid) {
    return AdapterWebSocketChannel(OkHttpWebSocket.connect(uri));
  }
  return WebSocketChannel.connect(uri);
}
