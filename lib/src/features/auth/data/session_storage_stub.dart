import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';

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
}
