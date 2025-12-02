// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> showWebNotification(String title, String body) async {
  if (html.Notification.permission == 'default') {
    await html.Notification.requestPermission();
  }
  if (html.Notification.permission == 'granted') {
    html.Notification(title, body: body);
  }
}
