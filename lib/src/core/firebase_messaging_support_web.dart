import 'package:firebase_messaging/firebase_messaging.dart';

Future<bool> messagingSupported() async {
  try {
    return await FirebaseMessaging.instance.isSupported();
  } catch (_) {
    return false;
  }
}
