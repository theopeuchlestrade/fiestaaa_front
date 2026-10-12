import 'dart:async';

import 'api_response.dart';
import '../features/events/domain/event_model.dart';
import '../features/invitations/domain/invitation_model.dart';
import 'navigation_diagnostics.dart';

/// In-memory data only. Permission evidence is a separate, short-lived resource.
class EventDataStore {
  EventDataStore({DateTime Function()? now, this.capacity = 10})
    : _now = now ?? _elapsedNow;
  static final _clock = Stopwatch()..start();
  static DateTime _elapsedNow() => DateTime.fromMicrosecondsSinceEpoch(
    _clock.elapsedMicroseconds,
    isUtc: true,
  );
  static final instance = EventDataStore();
  static const freshness = Duration(seconds: 30);
  static const retention = Duration(minutes: 5);
  final DateTime Function() _now;
  final int capacity;
  String? _token;
  String? _identity;
  String? _accountId;
  int _sessionGeneration = 0;
  final _events = <int, _EventBucket>{};
  final _changes = StreamController<EventAccessChange>.broadcast();
  Stream<EventAccessChange> get accessChanges => _changes.stream;
  int get generation => _sessionGeneration;

  void bind(String token, String identity, {String? accountId}) {
    if (_token == token && _identity == identity && _accountId == accountId) {
      return;
    }
    clear();
    _token = token;
    _identity = identity;
    _accountId = accountId;
  }

  bool applies(String? token) => _token != null && token == _token;
  void clear() {
    _sessionGeneration++;
    _events.clear();
    _token = null;
    _identity = null;
    _accountId = null;
  }

  _EventBucket _touch(int eventId) {
    final bucket = _events.remove(eventId) ?? _EventBucket();
    _events[eventId] = bucket;
    while (_events.length > capacity) {
      _events.remove(_events.keys.first);
    }
    return bucket;
  }

  T? peek<T>(String token, int eventId, String resource, {bool fresh = false}) {
    if (!applies(token)) return null;
    final bucket = _events[eventId];
    if (bucket == null) return null;
    final entry = bucket.values[resource];
    if (entry == null) return null;
    final age = _now().difference(entry.time);
    if (age.isNegative || age >= retention) {
      bucket.values.remove(resource);
      return null;
    }
    if (fresh && (entry.invalidated || age >= freshness)) return null;
    _touch(eventId);
    return entry.value as T?;
  }

  bool isFresh(String token, int eventId, String resource) {
    if (!applies(token)) return false;
    final entry = _events[eventId]?.values[resource];
    return entry != null &&
        !entry.invalidated &&
        !_now().difference(entry.time).isNegative &&
        _now().difference(entry.time) < freshness;
  }

  bool canReuseProtected(String token, int eventId) {
    final context = peek<EventModel>(token, eventId, 'context', fresh: true);
    if (context == null) return false;
    if (context.ownerEmail.toLowerCase() == _identity?.toLowerCase()) {
      return true;
    }
    return peek<InvitationModel>(
          token,
          eventId,
          'access',
          fresh: true,
        )?.status ==
        'Accepted';
  }

  Future<T> read<T>(
    String? token,
    int eventId,
    String resource,
    Future<T> Function() loader,
  ) async {
    if (!applies(token)) return loader();
    final bucket = _touch(eventId);
    if (isFresh(token!, eventId, resource) &&
        (resource == 'context' ||
            resource == 'access' ||
            canReuseProtected(token, eventId))) {
      return bucket.values[resource]!.value as T;
    }
    final existing = bucket.pending[resource];
    if (existing != null) return await existing as T;
    final session = _sessionGeneration;
    final generation = bucket.generations[resource] ?? 0;
    late final Future<T> pending;
    pending = NavigationDiagnostics.instance
        .measure(resource, loader)
        .then((value) {
          if (session != _sessionGeneration ||
              !identical(_events[eventId], bucket) ||
              generation != (bucket.generations[resource] ?? 0)) {
            throw const StaleEventData();
          }
          bucket.values[resource] = _Snapshot(value, _now());
          return value;
        })
        .catchError((Object error, StackTrace stack) {
          if (session == _sessionGeneration &&
              identical(_events[eventId], bucket) &&
              generation == (bucket.generations[resource] ?? 0) &&
              error is ApiException) {
            if (error.statusCode == 401) {
              clear();
              _changes.add(
                EventAccessChange(eventId, true, _sessionGeneration),
              );
            } else if ([403, 404, 410].contains(error.statusCode)) {
              invalidateEvent(eventId, access: true, denied: true);
            }
          }
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() {
          if (identical(bucket.pending[resource], pending)) {
            bucket.pending.remove(resource);
          }
        });
    bucket.pending[resource] = pending;
    return pending;
  }

  void invalidate(int eventId, Iterable<String> resources) {
    final bucket = _events[eventId];
    if (bucket == null) return;
    for (final resource in resources) {
      bucket.generations[resource] = (bucket.generations[resource] ?? 0) + 1;
      bucket.values[resource]?.invalidated = true;
      bucket.pending.remove(resource);
    }
  }

  void invalidateEvent(
    int eventId, {
    bool access = false,
    bool denied = false,
  }) {
    final bucket = _events[eventId];
    if (bucket != null) {
      invalidate(eventId, {...bucket.values.keys, ...bucket.pending.keys});
      if (access) bucket.values.clear();
    }
    if (access) {
      _changes.add(EventAccessChange(eventId, denied, _sessionGeneration));
    }
  }

  void invalidateAll({bool access = false}) {
    for (final id in _events.keys.toList()) {
      invalidateEvent(id, access: access);
    }
  }

  /// Writes outside an event path (e.g. /carpools/:id) conservatively invalidate
  /// retained events. No hidden module is fetched as a result.
  void mutation(String? token, Uri uri) {
    if (!applies(token)) return;
    final parts = uri.pathSegments;
    final index = parts.indexOf('events');
    final event = index >= 0 && parts.length > index + 1
        ? int.tryParse(parts[index + 1])
        : null;
    final membership = parts.contains('invitations');
    if (event != null) {
      invalidateEvent(event, access: membership);
    } else if (parts.contains('invitations') ||
        parts.contains('carpools') ||
        parts.contains('items') ||
        parts.contains('polls') ||
        parts.contains('expenses') ||
        parts.contains('me')) {
      invalidateAll(access: membership || parts.contains('me'));
    }
  }

  final _processedMessages = Expando<bool>();
  void observeRealtime(
    String token,
    int eventId,
    Map<String, dynamic> message, {
    bool reconnect = false,
  }) {
    if (_processedMessages[message] == true) return;
    _processedMessages[message] = true;
    final type = message['type'];
    if (type is! String) return;
    realtime(
      token,
      eventId,
      type == 'realtime.ready' && reconnect ? 'realtime.reconnected' : type,
    );
  }

  void realtime(String token, int eventId, String type) {
    if (!applies(token)) return;
    switch (type) {
      case 'event.updated':
      case 'realtime.reconnected':
        invalidateEvent(eventId);
      case 'event.deleted':
      case 'event.invitations.changed':
        invalidateEvent(eventId, access: true);
      case 'event.items.changed':
        final keys = {
          ...?_events[eventId]?.values.keys,
          ...?_events[eventId]?.pending.keys,
        }.where((k) => k.startsWith('items:') || k == 'contributions').toList();
        invalidate(eventId, {...keys, 'contributions', 'items:all'});
      case 'event.polls.changed':
        invalidate(eventId, ['polls']);
      case 'event_expenses_changed':
        invalidate(eventId, ['expenses', 'expense-summary']);
      case 'carpool_created':
      case 'carpool_updated':
      case 'carpool_deleted':
      case 'carpool_joined':
      case 'carpool_left':
      case 'event.carpools.changed':
        final keys = {
          ...?_events[eventId]?.values.keys,
          ...?_events[eventId]?.pending.keys,
        }.where((k) => k.startsWith('carpools:'));
        invalidate(eventId, keys.toList());
    }
  }
}

class StaleEventData implements Exception {
  const StaleEventData();
}

class _EventBucket {
  final values = <String, _Snapshot>{};
  final pending = <String, Future<Object?>>{};
  final generations = <String, int>{};
}

class _Snapshot {
  _Snapshot(this.value, this.time);
  final Object? value;
  final DateTime time;
  bool invalidated = false;
}

class EventAccessChange {
  const EventAccessChange(this.eventId, this.denied, this.generation);
  final int eventId;
  final bool denied;
  final int generation;
}
