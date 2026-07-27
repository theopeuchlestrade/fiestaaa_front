import 'dart:convert';

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
  static const _sessionKey = 'fiestaaa_session_v2';
  static const _tokenKey = 'fiestaaa_token';
  static const _publicIdKey = 'fiestaaa_public_id';
  static const _emailKey = 'fiestaaa_email';
  static const _handleKey = 'fiestaaa_handle';
  static SessionStorageBackend _storage =
      const _FlutterSecureSessionStorageBackend();
  static final Map<String, String> _fallback = <String, String>{};

  static Future<void> save(SessionData session) async {
    final encoded = jsonEncode({
      'token': session.token,
      'publicId': session.publicId,
      'email': session.email,
      'handle': session.handle,
    });
    try {
      await _storage.write(key: _sessionKey, value: encoded);
      await _deleteLegacyFields();
    } catch (_) {
      _fallback
        ..clear()
        ..[_sessionKey] = encoded;
    }
  }

  static Future<SessionData?> load() async {
    try {
      final encoded = await _storage.read(key: _sessionKey);
      if (encoded != null) return _decodeSession(encoded);

      // One-release compatibility with sessions written before v2.
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
      final encoded = _fallback[_sessionKey];
      return encoded == null ? null : _decodeSession(encoded);
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
      await _deleteLegacyFields();
    } catch (_) {
      // Secure storage may be unavailable in tests or on unsupported hosts.
    } finally {
      _fallback.clear();
    }
  }

  static Future<bool> shouldProbeCookieSession() async => false;

  static SessionData? _decodeSession(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return null;
      final token = value['token'];
      final email = value['email'];
      if (token is! String ||
          token.isEmpty ||
          email is! String ||
          email.isEmpty) {
        return null;
      }
      return SessionData(
        token: token,
        email: email,
        handle: value['handle'] as String?,
        publicId: value['publicId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteLegacyFields() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _publicIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _handleKey);
  }

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
