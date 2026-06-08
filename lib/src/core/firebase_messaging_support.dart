import 'firebase_messaging_support_stub.dart'
    if (dart.library.html) 'firebase_messaging_support_web.dart';

Future<bool> isFirebaseMessagingSupported() {
  return messagingSupported();
}
