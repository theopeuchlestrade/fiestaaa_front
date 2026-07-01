import 'dart:async';

import 'package:fiestaaa_front/src/core/feature_controller.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';

class EventDetailController extends FeatureController {
  EventDetailController({
    required this.token,
    required this.eventId,
    EventsApi? api,
    Stream<Map<String, dynamic>>? realtime,
  }) : api = api ?? EventsApi() {
    _subscription = realtime?.listen((message) {
      if (message['type'] == 'events.changed') refresh();
    });
  }

  final String token;
  final int eventId;
  final EventsApi api;
  EventModel? event;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  Future<void> load() async {
    event = await api.fetchEventById(token: token, eventId: eventId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    api.dispose();
    super.dispose();
  }
}
