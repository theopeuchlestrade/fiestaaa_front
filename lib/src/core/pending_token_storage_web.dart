import 'package:web/web.dart' as web;

class PendingTokenStorage {
  static String? read(String key) => web.window.sessionStorage.getItem(key);
  static void write(String key, String value) =>
      web.window.sessionStorage.setItem(key, value);
  static void remove(String key) => web.window.sessionStorage.removeItem(key);
}
