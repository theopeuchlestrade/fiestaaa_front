import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:web/web.dart' as web;

class SessionStorage {
  static const _tokenKey = 'fiestaaa_token';
  static const _emailKey = 'fiestaaa_email';
  static const _handleKey = 'fiestaaa_handle';

  static Future<void> save(SessionData session) async {
    web.window.sessionStorage.setItem(_tokenKey, session.token);
    web.window.sessionStorage.setItem(_emailKey, session.email);
    if (session.handle != null) {
      web.window.sessionStorage.setItem(_handleKey, session.handle!);
    } else {
      web.window.sessionStorage.removeItem(_handleKey);
    }
  }

  static Future<SessionData?> load() async {
    final token = web.window.sessionStorage.getItem(_tokenKey);
    final email = web.window.sessionStorage.getItem(_emailKey);
    if (token == null || email == null) return null;
    final handle = web.window.sessionStorage.getItem(_handleKey);
    return SessionData(token: token, email: email, handle: handle);
  }

  static Future<void> clear() async {
    web.window.sessionStorage.removeItem(_tokenKey);
    web.window.sessionStorage.removeItem(_emailKey);
    web.window.sessionStorage.removeItem(_handleKey);
  }
}
