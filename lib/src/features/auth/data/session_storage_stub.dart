import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter/foundation.dart';

abstract class SessionStorageBackend {
  Future<void> write({required String key, String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class SessionStorage {
  static SessionData? _session;

  static Future<void> save(SessionData session) async {
    _session = session;
  }

  static Future<SessionData?> load() async => _session;

  static Future<void> clear() async {
    _session = null;
  }

  static Future<bool> shouldProbeCookieSession() async => false;

  @visibleForTesting
  static void debugSetStorageBackend(SessionStorageBackend storage) {}

  @visibleForTesting
  static void debugResetStorageBackend() {}
}
