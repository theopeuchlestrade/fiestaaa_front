import 'dart:async';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces a burst into a trailing read of the latest state', () async {
    final queue = RefreshQueue();
    final blocker = Completer<void>();
    var calls = 0;
    var serverValue = 1;
    var displayed = 0;
    Future<void> load() async {
      calls++;
      final snapshot = serverValue;
      if (calls == 1) await blocker.future;
      displayed = snapshot;
    }

    final first = queue.run('events', load);
    serverValue = 2;
    final second = queue.run('events', load);
    queue.run('events', load);
    queue.run('events', load);
    blocker.complete();
    await Future.wait([first, second]);
    expect(calls, 2);
    expect(displayed, 2);
    queue.dispose();
  });

  test('failure allows retry and disposal discards queued reads', () async {
    final queue = RefreshQueue();
    await expectLater(
      queue.run('event', () async {
        throw StateError('offline');
      }),
      throwsStateError,
    );
    var calls = 0;
    await queue.run('event', () async {
      calls++;
    });
    final blocker = Completer<void>();
    final pending = queue.run('event', () async {
      await blocker.future;
    });
    queue.run('event', () async {
      calls++;
    });
    queue.dispose();
    blocker.complete();
    await pending;
    await queue.run('event', () async {
      calls++;
    });
    expect(calls, 1);
  });
}
