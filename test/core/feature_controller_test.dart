import 'dart:async';

import 'package:fiestaaa_front/src/core/feature_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Controller extends FeatureController {
  int calls = 0;
  Object? failure;
  Completer<void>? blocker;

  @override
  Future<void> load() async {
    calls++;
    if (failure case final value?) throw value;
    await blocker?.future;
  }
}

void main() {
  test('coalesces concurrent refresh calls', () async {
    final controller = _Controller()..blocker = Completer<void>();

    final first = controller.refresh();
    final second = controller.refresh();

    expect(controller.calls, 1);
    expect(controller.loading, isTrue);
    controller.blocker!.complete();
    await Future.wait([first, second]);
    expect(controller.calls, 1);
    expect(controller.loading, isFalse);
  });

  test('captures errors and remains refreshable', () async {
    final controller = _Controller()..failure = StateError('broken');

    await controller.refresh();
    expect(controller.error, isA<StateError>());

    controller.failure = null;
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.calls, 2);
  });

  test('ignores notifications after disposal', () async {
    final controller = _Controller()..blocker = Completer<void>();
    final refresh = controller.refresh();
    controller.dispose();
    controller.blocker!.complete();
    await refresh;
  });
}
