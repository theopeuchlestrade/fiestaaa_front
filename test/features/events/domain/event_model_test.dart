import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson infers optional features when enabled_features is absent', () {
    final event = EventModel.fromJson({
      'event_id': 1,
      'name_event': 'Summer Party',
      'description': 'Beach vibes',
      'date_event': '2030-08-10',
      'start_time': '21:30:00',
      'address': '123 Ocean Drive',
      'latitude': '48.8566',
      'longitude': 2.3522,
      'payment_provider_id': 2,
      'payment_identifier': 'pay-me',
      'payment_requested_amount': 18.5,
      'payment_per_person': true,
      'owner_email': 'owner@example.com',
      'playlist_url': 'https://open.spotify.com/playlist/abc',
      'playlist_provider': 'spotify',
      'invitation_deadline': '',
    });

    expect(event.enabledFeatures, [
      eventFeatureCarpools,
      eventFeaturePolls,
      eventFeatureItems,
      eventFeaturePlaylist,
      eventFeaturePayment,
    ]);
    expect(event.hasCoordinates, isTrue);
    expect(event.formattedTime, '21:30');
  });

  test(
    'fromJson filters invalid enabled_features and keeps unique entries',
    () {
      final event = EventModel.fromJson({
        'event_id': 1,
        'name_event': 'House Party',
        'description': 'All night long',
        'date_event': '2030-02-14',
        'start_time': '18:00:00',
        'address': '42 Party Street',
        'latitude': null,
        'longitude': null,
        'payment_provider_id': null,
        'payment_identifier': null,
        'payment_requested_amount': null,
        'payment_per_person': false,
        'owner_email': 'owner@example.com',
        'playlist_url': null,
        'playlist_provider': null,
        'enabled_features': ['items', 'PAYMENT', 'items', 'unknown', 'polls'],
        'invitation_deadline': null,
      });

      expect(event.enabledFeatures, ['items', 'payment', 'polls']);
      expect(event.startDateTime, DateTime(2030, 2, 14, 18));
    },
  );

  test('EventPayload serializes dates and durations to API format', () {
    final payload = EventPayload(
      name: 'Brunch',
      description: 'Sunday brunch',
      date: DateTime(2030, 5, 4),
      startTime: const Duration(hours: 11, minutes: 5),
      address: '10 Main Street',
      invitationDeadline: DateTime(2030, 5, 1),
      latitude: 48.0,
      longitude: 2.0,
      paymentPerPerson: true,
      enabledFeatures: const ['items', 'polls'],
    );

    expect(payload.toJson(), {
      'name_event': 'Brunch',
      'description': 'Sunday brunch',
      'date_event': '2030-05-04',
      'start_time': '11:05:00',
      'address': '10 Main Street',
      'invitation_deadline': '2030-05-01',
      'latitude': 48.0,
      'longitude': 2.0,
      'payment_provider_id': null,
      'payment_identifier': null,
      'payment_requested_amount': null,
      'payment_per_person': true,
      'playlist_url': null,
      'playlist_provider': null,
      'enabled_features': ['items', 'polls'],
    });
  });
}
