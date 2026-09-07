import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versioned, account-scoped local storage. Never includes authentication data.
class EventDraftStore {
  const EventDraftStore();
  String key(String account) =>
      'event_draft.v1.${base64Url.encode(utf8.encode(account.trim().toLowerCase()))}';
  Future<Map<String, dynamic>?> read(String account) async {
    final raw = (await SharedPreferences.getInstance()).getString(key(account));
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid draft');
    }
    final data = decoded;
    if (data['version'] != 1 || data['fields'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported draft');
    }
    final fields = data['fields'] as Map<String, dynamic>;
    for (final key in [
      'name',
      'description',
      'address',
      'date',
      'timezone',
      'time',
      'paymentIdentifier',
      'paymentAmount',
      'playlistUrl',
    ]) {
      if (fields[key] is! String) {
        throw const FormatException('Invalid draft field');
      }
    }
    DateTime.parse(fields['date'] as String);
    for (final key in ['endDate', 'deadline']) {
      if (fields[key] != null) {
        if (fields[key] is! String) throw const FormatException('Invalid date');
        DateTime.parse(fields[key] as String);
      }
    }
    for (final key in ['hasEnd', 'perPerson']) {
      if (fields[key] is! bool) {
        throw const FormatException('Invalid draft flag');
      }
    }
    if (fields['features'] is! List ||
        !(fields['features'] as List).every((e) => e is String)) {
      throw const FormatException('Invalid modules');
    }
    for (final key in ['time', 'endTime']) {
      final raw = fields[key];
      if (raw == null && key == 'endTime') continue;
      if (raw is! String ||
          !RegExp(r'^([01]?\d|2[0-3]):([0-5]?\d)$').hasMatch(raw)) {
        throw const FormatException('Invalid time');
      }
    }
    if (fields['provider'] != null && fields['provider'] is! int) {
      throw const FormatException('Invalid provider');
    }
    if (fields['playlistProvider'] != null &&
        fields['playlistProvider'] is! String) {
      throw const FormatException('Invalid provider');
    }
    return fields;
  }

  Future<void> write(String account, Map<String, dynamic> fields) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      key(account),
      jsonEncode({'version': 1, 'fields': fields}),
    );
    if (!ok) throw StateError('Draft storage unavailable');
  }

  Future<void> delete(String account) async {
    if (!await (await SharedPreferences.getInstance()).remove(key(account))) {
      throw StateError('Draft storage unavailable');
    }
  }
}

/// Shared dirty tracking for both forms; persistence is enabled only for create.
class EventFormSession extends ChangeNotifier {
  EventFormSession({
    required this.account,
    required this.persist,
    this.store = const EventDraftStore(),
  });
  final String account;
  final bool persist;
  final EventDraftStore store;
  Map<String, dynamic> _fields = {};
  String _saved = '';
  String _current = '';
  Timer? _timer;
  Future<void> _writes = Future.value();
  bool ready = false;
  bool failed = false;
  bool savedDraft = false;
  bool _disposed = false;
  bool get dirty => ready && _current != _saved;
  void start(Map<String, dynamic> fields, {bool restored = false}) {
    _fields = Map.of(fields);
    _saved = _current = jsonEncode(fields);
    ready = true;
    savedDraft = restored;
  }

  void changed(Map<String, dynamic> fields) {
    if (!ready || _disposed) return;
    final next = jsonEncode(fields);
    if (_current == next) return;
    _fields = Map.of(fields);
    _current = next;
    _timer?.cancel();
    if (persist) _timer = Timer(const Duration(milliseconds: 500), flush);
    notifyListeners();
  }

  Future<bool> flush() async {
    _timer?.cancel();
    if (!persist || !dirty) return !dirty;
    final fields = Map<String, dynamic>.from(_fields), revision = _current;
    _writes = _writes.then((_) async {
      try {
        await store.write(account, fields);
        _saved = revision;
        failed = false;
        savedDraft = true;
      } catch (_) {
        failed = true;
      }
      if (!_disposed) notifyListeners();
    });
    await _writes;
    return !dirty;
  }

  Future<void> complete() async {
    _timer?.cancel();
    ready = false;
    await _writes;
    if (persist) await store.delete(account);
    _saved = _current;
    savedDraft = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// The route consults the mounted creation form before replacing its URL.
class EventFormExitGuard {
  static Future<bool> Function()? onExit;
  static Future<bool> leave() async => await onExit?.call() ?? true;
}
