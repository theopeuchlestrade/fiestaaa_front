import 'dart:async';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/event_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _event(int id, String name) => EventModel(
  id: id,
  name: name,
  description: 'Description',
  date: DateTime(2099, 7, id),
  startTime: const Duration(hours: 20),
  endDate: null,
  endTime: null,
  address: 'Paris',
  latitude: null,
  longitude: null,
  paymentProviderId: null,
  paymentIdentifier: null,
  paymentRequestedAmount: null,
  paymentPerPerson: false,
  ownerEmail: 'me@example.com',
  playlistUrl: null,
  playlistProvider: null,
  enabledFeatures: const [],
);

class _Api extends EventsApi {
  String name = 'Before disconnect';
  int reads = 0;
  Completer<void>? blocker;
  bool offline = false;
  @override
  Future<EventModel> fetchEventById({
    required String token,
    required int eventId,
  }) async {
    reads++;
    final snapshot = name;
    if (offline) throw StateError('offline');
    await blocker?.future;
    return _event(eventId, snapshot);
  }

  @override
  void dispose() {}
}

void main() {
  test(
    'readiness restores changes missed offline and retains in-flight invalidations',
    () async {
      final stream = StreamController<Map<String, dynamic>>.broadcast(
        sync: true,
      );
      final api = _Api();
      final controller = EventDetailController(
        token: 'token',
        eventId: 1,
        api: api,
        realtime: stream.stream,
      );
      await controller.refresh();
      expect(controller.event!.name, 'Before disconnect');
      api.blocker = Completer<void>();
      final refreshing = controller.refresh();
      api.name = 'Changed while disconnected';
      stream.add({'type': 'realtime.ready'});
      stream.add({'type': 'event.updated', 'event_id': 1});
      api.blocker!.complete();
      await refreshing;
      expect(controller.event!.name, 'Changed while disconnected');
      expect(api.reads, 3);
      stream.add({'type': 'event.updated', 'event_id': 2});
      expect(api.reads, 3);
      controller.dispose();
      await stream.close();
    },
  );

  test('failed resync retains data and can be retried', () async {
    final api = _Api();
    final controller = EventDetailController(
      token: 'token',
      eventId: 1,
      api: api,
    );
    await controller.refresh();
    api.offline = true;
    await controller.refresh();
    expect(controller.error, isNotNull);
    expect(controller.event!.name, 'Before disconnect');
    api.offline = false;
    api.name = 'Recovered';
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.event!.name, 'Recovered');
    controller.dispose();
  });
}
