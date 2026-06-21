import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStorageBackend {
  Future<void> write({required String key, String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class _FlutterSecureSessionStorageBackend implements SessionStorageBackend {
  const _FlutterSecureSessionStorageBackend();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> write({required String key, String? value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

class SessionStorage {
  static const _tokenKey = 'fiestaaa_token';
  static const _publicIdKey = 'fiestaaa_public_id';
  static const _emailKey = 'fiestaaa_email';
  static const _handleKey = 'fiestaaa_handle';
  static SessionStorageBackend _storage =
      const _FlutterSecureSessionStorageBackend();
  static final Map<String, String> _fallback = <String, String>{};

  static Future<void> save(SessionData session) async {
    try {
      await _storage.write(key: _tokenKey, value: session.token);
      await _storage.write(key: _publicIdKey, value: session.publicId);
      await _storage.write(key: _emailKey, value: session.email);
      if (session.handle != null) {
        await _storage.write(key: _handleKey, value: session.handle);
      } else {
        await _storage.delete(key: _handleKey);
      }
    } catch (_) {
      _fallback[_tokenKey] = session.token;
      if (session.publicId != null) {
        _fallback[_publicIdKey] = session.publicId!;
      } else {
        _fallback.remove(_publicIdKey);
      }
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
      final publicId = await _storage.read(key: _publicIdKey);
      final email = await _storage.read(key: _emailKey);
      if (token == null || email == null) return null;
      final handle = await _storage.read(key: _handleKey);
      return SessionData(
        token: token,
        email: email,
        handle: handle,
        publicId: publicId,
      );
    } catch (_) {
      final token = _fallback[_tokenKey];
      final publicId = _fallback[_publicIdKey];
      final email = _fallback[_emailKey];
      if (token == null || email == null) return null;
      return SessionData(
        token: token,
        email: email,
        handle: _fallback[_handleKey],
        publicId: publicId,
      );
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _publicIdKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _handleKey);
    } catch (_) {
      // Secure storage may be unavailable in tests or on unsupported hosts.
    } finally {
      _fallback.clear();
    }
  }

  static Future<bool> shouldProbeCookieSession() async => false;

  @visibleForTesting
  static void debugSetStorageBackend(SessionStorageBackend storage) {
    _storage = storage;
    _fallback.clear();
  }

  @visibleForTesting
  static void debugResetStorageBackend() {
    _storage = const _FlutterSecureSessionStorageBackend();
    _fallback.clear();
  }
}
