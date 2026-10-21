import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config.dart';
import '../../../core/api_response.dart';
import '../domain/session_data.dart';
import 'session_storage.dart';

/// Coordinates every API client so simultaneous calls rotate credentials once.
/// Renewal happens before sending the request, including uploads and mutations.
class MobileSessionManager {
  static final instance = MobileSessionManager();
  final _changes = StreamController<SessionData>.broadcast();
  Stream<SessionData> get changes => _changes.stream;
  SessionData? _session;
  SessionData? get session => _session;
  final _tokens = <String>{};
  Future<SessionData>? _pending;
  int _generation = 0;

  void bind(SessionData session) {
    if (_session?.token == session.token) {
      _session = session;
      return;
    }
    _generation++;
    _tokens
      ..clear()
      ..add(session.token);
    _session = session;
  }

  Future<void> clear() async {
    _generation++;
    _session = null;
    _tokens.clear();
    try {
      await _pending;
    } catch (_) {
      /* Invalidated session is discarded. */
    }
  }

  bool accepts(String token) => _session != null && _tokens.contains(token);

  Future<String> tokenFor(String token, http.Client client) async {
    final current = _session;
    if (current == null || !_tokens.contains(token)) return token;
    if (current.refreshToken != null && !_needsRenewal(current.token)) {
      return current.token;
    }
    // Unrecognized legacy credentials use the existing server validation.
    if (current.refreshToken == null && _expiry(current.token) == null) {
      return current.token;
    }
    final generation = _generation;
    final pending = _pending ??= _renew(current, client, generation);
    try {
      final renewed = await pending;
      if (generation != _generation) throw const SessionChangedException();
      return renewed.token;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
  }

  Future<SessionData> _renew(
    SessionData previous,
    http.Client client,
    int generation,
  ) async {
    final response = await client
        .post(
          buildApiUri('/auth/refresh'),
          headers: {
            'Content-Type': 'application/json',
            'X-Fiestaaa-Auth-Response': 'bearer-refresh',
            if (previous.refreshToken == null)
              'Authorization': 'Bearer ${previous.token}',
          },
          body: jsonEncode({'refresh_token': previous.refreshToken}),
        )
        .timeout(const Duration(seconds: 15));
    if (generation != _generation) throw const SessionChangedException();
    if (response.statusCode == 401) throw const SessionRevokedException();
    if (response.statusCode != 200) {
      throw apiExceptionFromResponse(
        response,
        fallbackMessage: 'Session renewal failed',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'];
    final refresh = data['refresh_token'];
    if (token is! String ||
        token.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const FormatException('Invalid session renewal');
    }
    final renewed = previous.copyWith(
      token: token,
      refreshToken: refresh,
      email: data['email'] as String?,
      handle: data['handle'] as String?,
      publicId: data['public_id'] as String?,
    );
    // Save the rotated secret before allowing any dependent API requests.
    await SessionStorage.save(renewed);
    if (generation != _generation) throw const SessionChangedException();
    _tokens.add(renewed.token);
    _session = renewed;
    _changes.add(renewed);
    return renewed;
  }

  bool _needsRenewal(String token) {
    final expiry = _expiry(token);
    return expiry == null ||
        expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
  }

  int? _expiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      return (jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>)['exp']
          as int?;
    } catch (_) {
      return null;
    }
  }
}

class SessionRevokedException implements Exception {
  const SessionRevokedException();
}

class SessionChangedException implements Exception {
  const SessionChangedException();
}
