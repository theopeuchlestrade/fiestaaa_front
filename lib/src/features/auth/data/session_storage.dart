import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'fiestaaa_token';
  static const _emailKey = 'fiestaaa_email';
  static const _handleKey = 'fiestaaa_handle';

  static Future<void> save(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_emailKey, session.email);
    if (session.handle != null) {
      await prefs.setString(_handleKey, session.handle!);
    } else {
      await prefs.remove(_handleKey);
    }
  }

  static Future<SessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final email = prefs.getString(_emailKey);
    if (token == null || email == null) return null;
    final handle = prefs.getString(_handleKey);
    return SessionData(token: token, email: email, handle: handle);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_handleKey);
  }
}
