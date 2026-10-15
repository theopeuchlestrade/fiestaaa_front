import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';

EventModel calendarEvent([Map<String, dynamic> overrides = const {}]) =>
    EventModel.fromJson({
      'event_id': 42,
      'name_event': 'Fête 🎉',
      'description': 'Bienvenue !',
      'date_event': '2026-07-14',
      'start_time': '20:30:00',
      'address': '10 rue de la Paix, Paris',
      'timezone': 'Europe/Paris',
      ...overrides,
    });
