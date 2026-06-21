import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

abstract class SessionStorageBackend {
  Future<void> write({required String key, String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class SessionStorage {
  static const _publicIdKey = 'fiestaaa_public_id';
  static const _emailKey = 'fiestaaa_email';
  static const _handleKey = 'fiestaaa_handle';
  static const _cookieSessionHintKey = 'fiestaaa_cookie_session';

  static Future<void> save(SessionData session) async {
    if (session.publicId != null) {
      web.window.sessionStorage.setItem(_publicIdKey, session.publicId!);
    } else {
      web.window.sessionStorage.removeItem(_publicIdKey);
    }
    web.window.sessionStorage.setItem(_emailKey, session.email);
    if (session.handle != null) {
      web.window.sessionStorage.setItem(_handleKey, session.handle!);
    } else {
      web.window.sessionStorage.removeItem(_handleKey);
    }
    web.window.localStorage.setItem(_cookieSessionHintKey, '1');
  }

  static Future<SessionData?> load() async {
    final publicId = web.window.sessionStorage.getItem(_publicIdKey);
    final email = web.window.sessionStorage.getItem(_emailKey);
    if (email == null) return null;
    final handle = web.window.sessionStorage.getItem(_handleKey);
    return SessionData(
      token: '',
      email: email,
      handle: handle,
      publicId: publicId,
    );
  }

  static Future<void> clear() async {
    web.window.sessionStorage.removeItem(_publicIdKey);
    web.window.sessionStorage.removeItem(_emailKey);
    web.window.sessionStorage.removeItem(_handleKey);
    web.window.localStorage.removeItem(_cookieSessionHintKey);
  }

  static Future<bool> shouldProbeCookieSession() async {
    return web.window.localStorage.getItem(_cookieSessionHintKey) == '1';
  }

  @visibleForTesting
  static void debugSetStorageBackend(SessionStorageBackend storage) {}

  @visibleForTesting
  static void debugResetStorageBackend() {}
}
