import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _tokenKey = 'fiestaaa_token';
  static const _emailKey = 'fiestaaa_email';
  static const _handleKey = 'fiestaaa_handle';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final Map<String, String> _fallback = <String, String>{};

  static Future<void> save(SessionData session) async {
    try {
      await _storage.write(key: _tokenKey, value: session.token);
      await _storage.write(key: _emailKey, value: session.email);
      if (session.handle != null) {
        await _storage.write(key: _handleKey, value: session.handle);
      } else {
        await _storage.delete(key: _handleKey);
      }
    } catch (_) {
      _fallback[_tokenKey] = session.token;
      _fallback[_emailKey] = session.email;
      if (session.handle != null) {
        _fallback[_handleKey] = session.handle!;
      } else {
        _fallback.remove(_handleKey);
      }
    }
  }

  static Future<SessionData?> load() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final email = await _storage.read(key: _emailKey);
      if (token == null || email == null) return null;
      final handle = await _storage.read(key: _handleKey);
      return SessionData(token: token, email: email, handle: handle);
    } catch (_) {
      final token = _fallback[_tokenKey];
      final email = _fallback[_emailKey];
      if (token == null || email == null) return null;
      return SessionData(
        token: token,
        email: email,
        handle: _fallback[_handleKey],
      );
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _handleKey);
    } catch (_) {
      _fallback.clear();
    }
  }
}
