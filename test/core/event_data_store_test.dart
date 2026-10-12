import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fiestaaa_front/src/core/event_data_store.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/navigation_diagnostics.dart';

void main() {
  late EventDataStore store;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026);
    store = EventDataStore(now: () => now, capacity: 2)..bind('session', 'qa');
  });
  test(
    'fresh data reuses reads, stale snapshot survives transient failure, expires',
    () async {
      var calls = 0;
      Future<String> load() async => 'value-${++calls}';
      await store.read('session', 1, 'context', load);
      expect(await store.read('session', 1, 'context', load), 'value-1');
      now = now.add(const Duration(seconds: 30));
      expect(store.peek<String>('session', 1, 'context', fresh: true), isNull);
      expect(store.peek<String>('session', 1, 'context'), 'value-1');
      await expectLater(
        store.read(
          'session',
          1,
          'context',
          () async => throw Exception('offline'),
        ),
        throwsException,
      );
      expect(store.peek<String>('session', 1, 'context'), 'value-1');
      now = now.add(const Duration(minutes: 5));
      expect(store.peek<String>('session', 1, 'context'), isNull);
    },
  );
  test('LRU eviction respects recent access', () async {
    await store.read('session', 1, 'context', () async => 'one');
    await store.read('session', 2, 'context', () async => 'two');
    store.peek<String>('session', 1, 'context');
    await store.read('session', 3, 'context', () async => 'three');
    expect(store.peek<String>('session', 2, 'context'), isNull);
    expect(store.peek<String>('session', 1, 'context'), 'one');
  });
  test('identical in-flight reads share one operation', () async {
    var calls = 0;
    final pending = Completer<String>();
    Future<String> load() {
      calls++;
      return pending.future;
    }

    final first = store.read('session', 1, 'context', load);
    final second = store.read('session', 1, 'context', load);
    expect(calls, 1);
    pending.complete('result');
    expect(await first, 'result');
    expect(await second, 'result');
  });
  test(
    'invalidation discards older result without clearing newer request',
    () async {
      final pending = Completer<String>();
      final old = store.read('session', 1, 'context', () => pending.future);
      final rejected = expectLater(old, throwsA(isA<StaleEventData>()));
      store.invalidate(1, ['context']);
      await store.read('session', 1, 'context', () async => 'new');
      pending.complete('old');
      await rejected;
      expect(store.peek<String>('session', 1, 'context'), 'new');
    },
  );
  test('account switch and logout cannot repopulate data', () async {
    final pending = Completer<String>();
    final old = store.read('session', 1, 'context', () => pending.future);
    final rejected = expectLater(old, throwsA(isA<StaleEventData>()));
    store.bind('new', 'other');
    pending.complete('private');
    await rejected;
    expect(store.peek<String>('new', 1, 'context'), isNull);
    await store.read('new', 1, 'context', () async => 'new-private');
    store.clear();
    expect(store.peek<String>('new', 1, 'context'), isNull);
  });
  for (final status in [401, 403, 404, 410]) {
    test(
      'refusal $status clears affected snapshots and signals denied access',
      () async {
        await store.read('session', 1, 'context', () async => 'private');
        final event = store.accessChanges.first;
        await expectLater(
          store.read(
            'session',
            1,
            'other',
            () async => throw ApiException('refused', statusCode: status),
          ),
          throwsA(isA<ApiException>()),
        );
        expect((await event).denied, isTrue);
        expect(store.peek<String>('session', 1, 'context'), isNull);
      },
    );
  }
  test(
    'realtime invalidation discards an in-flight filtered item query',
    () async {
      final pending = Completer<String>();
      final old = store.read('session', 1, 'items:needs', () => pending.future);
      final rejected = expectLater(old, throwsA(isA<StaleEventData>()));
      store.realtime('session', 1, 'event.items.changed');
      pending.complete('outdated');
      await rejected;
      expect(store.peek<String>('session', 1, 'items:needs'), isNull);
    },
  );
  test('resource/query keys stay separate', () async {
    await store.read('session', 1, 'items:needs', () async => 1);
    await store.read('session', 1, 'items:personal', () async => 2);
    store.invalidate(1, ['items:needs']);
    expect(store.isFresh('session', 1, 'items:needs'), isFalse);
    expect(store.peek<int>('session', 1, 'items:personal'), 2);
  });
  test('mutation and realtime invalidation include hidden resources', () async {
    await store.read('session', 1, 'polls', () async => 1);
    await store.read('session', 1, 'expenses', () async => 2);
    store.realtime('session', 1, 'event.polls.changed');
    expect(store.isFresh('session', 1, 'polls'), isFalse);
    expect(store.isFresh('session', 1, 'expenses'), isTrue);
    store.mutation('session', Uri.parse('/events/1/expenses'));
    expect(store.isFresh('session', 1, 'expenses'), isFalse);
  });
  test(
    'diagnostics are disabled by default, bounded and resource-only',
    () async {
      final disabled = NavigationDiagnostics();
      await disabled.measure('context', () async => 1);
      expect(disabled.samples, isEmpty);
      final enabled = NavigationDiagnostics(enabled: true);
      for (var i = 0; i < 1002; i++) {
        enabled.record('context', const Duration(milliseconds: 2));
      }
      expect(enabled.samples.length, 1000);
      expect(enabled.samples.last.microseconds, 2000);
    },
  );
  test('an invalidated refusal cannot revoke newly loaded access', () async {
    final pending = Completer<String>();
    final old = store.read('session', 1, 'context', () => pending.future);
    final rejected = expectLater(old, throwsA(isA<ApiException>()));
    store.invalidateEvent(1);
    await store.read('session', 1, 'context', () async => 'new');
    pending.completeError(ApiException('old refusal', statusCode: 403));
    await rejected;
    expect(store.peek<String>('session', 1, 'context'), 'new');
  });
  test('shared immutable realtime message invalidates once', () async {
    await store.read('session', 1, 'polls', () async => 1);
    const message = {'type': 'event.polls.changed', 'event_id': 1};
    store.observeRealtime('session', 1, message);
    final fresh = store.read('session', 1, 'polls', () async => 2);
    store.observeRealtime('session', 1, message);
    expect(await fresh, 2);
  });
  test(
    'membership evidence expires independently and cannot authorize waiting guests',
    () async {
      final event = EventModel.fromJson({
        'event_id': 1,
        'name_event': 'Fixture',
        'description': 'Fictional',
        'date_event': '2099-01-01',
        'start_time': '18:00:00',
        'address': 'Fictional',
        'owner_email': 'other@example.invalid',
      });
      InvitationModel invitation(String status) => InvitationModel.fromJson({
        'event_id': 1,
        'email': 'qa',
        'status': status,
        'date_invi': '2026-01-01',
      });
      await store.read('session', 1, 'context', () async => event);
      await store.read<InvitationModel?>(
        'session',
        1,
        'access',
        () async => invitation('Accepted'),
      );
      expect(store.canReuseProtected('session', 1), isTrue);
      now = now.add(const Duration(seconds: 31));
      await store.read('session', 1, 'context', () async => event);
      expect(store.canReuseProtected('session', 1), isFalse);
      await store.read<InvitationModel?>(
        'session',
        1,
        'access',
        () async => invitation('Waiting'),
      );
      expect(store.canReuseProtected('session', 1), isFalse);
    },
  );
  test(
    'cookie-session account replacement clears data even with the same token',
    () async {
      store.bind('', 'same@example.invalid', accountId: 'old-id');
      await store.read('', 1, 'context', () async => 'private');
      store.bind('', 'same@example.invalid', accountId: 'new-id');
      expect(store.peek<String>('', 1, 'context'), isNull);
    },
  );
}
