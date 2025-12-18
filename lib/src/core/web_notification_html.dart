import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> showWebNotification(String title, String body) async {
  var permission = web.Notification.permission;
  if (permission == 'default') {
    final requested = await web.Notification.requestPermission().toDart;
    permission = requested.toDart;
  }
  if (permission == 'granted') {
    web.Notification(title, web.NotificationOptions(body: body));
  }
}
