import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'fiestaaa_token';
  static const _emailKey = 'fiestaaa_email';

  static Future<void> save(SessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_emailKey, session.email);
  }

  static Future<SessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final email = prefs.getString(_emailKey);
    if (token == null || email == null) return null;
    return SessionData(token: token, email: email);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
  }
}
