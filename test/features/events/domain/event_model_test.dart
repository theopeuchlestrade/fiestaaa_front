import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:flutter/widgets.dart';
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
      'end_date': null,
      'end_time': null,
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

  test('fromJson parses end schedule and expenses feature', () {
    final event = EventModel.fromJson({
      'event_id': 3,
      'name_event': 'Week-end',
      'description': 'Maison de campagne',
      'date_event': '2099-08-10',
      'start_time': '09:00:00',
      'end_date': '2099-08-12',
      'end_time': '17:30:00',
      'address': 'Rue des Lilas',
      'latitude': null,
      'longitude': null,
      'payment_provider_id': null,
      'payment_identifier': null,
      'payment_requested_amount': null,
      'payment_per_person': false,
      'owner_email': 'owner@example.com',
      'playlist_url': null,
      'playlist_provider': null,
      'enabled_features': ['expenses', 'items'],
      'invitation_deadline': null,
    });

    expect(event.hasEndDateTime, isTrue);
    expect(event.endDateTime, DateTime(2099, 8, 12, 17, 30));
    expect(event.isUpcoming, isTrue);
    expect(event.isReadOnly, isFalse);
    expect(event.enabledFeatures, ['expenses', 'items']);
  });

  test(
    'shortAddressSummary keeps street and city from a full geocoded address',
    () {
      final event = EventModel.fromJson({
        'event_id': 5,
        'name_event': 'Soirée',
        'description': 'Centre-ville',
        'date_event': '2030-06-21',
        'start_time': '20:00:00',
        'address':
            '115, Boulevard Lafayette, Le Brézet, Clermont-Ferrand, Puy-de-Dôme, Auvergne-Rhône-Alpes, France métropolitaine, 63000, France',
        'latitude': 45.7797,
        'longitude': 3.0863,
        'payment_provider_id': null,
        'payment_identifier': null,
        'payment_requested_amount': null,
        'payment_per_person': false,
        'owner_email': 'owner@example.com',
        'playlist_url': null,
        'playlist_provider': null,
        'enabled_features': ['items'],
        'invitation_deadline': null,
      });

      expect(event.shortAddressSummary.primary, '115 Boulevard Lafayette');
      expect(event.shortAddressSummary.secondary, 'Clermont-Ferrand');
      expect(event.shortAddressSummary.relation, EventAddressRelation.locality);
    },
  );

  test('shortAddressSummary keeps city and region for a city-only address', () {
    final event = EventModel.fromJson({
      'event_id': 6,
      'name_event': 'Balade',
      'description': 'Centre',
      'date_event': '2030-06-21',
      'start_time': '20:00:00',
      'address':
          'Clermont-Ferrand, Puy-de-Dôme, Auvergne-Rhône-Alpes, France métropolitaine, 63000, France',
      'latitude': 45.7797,
      'longitude': 3.0863,
      'payment_provider_id': null,
      'payment_identifier': null,
      'payment_requested_amount': null,
      'payment_per_person': false,
      'owner_email': 'owner@example.com',
      'playlist_url': null,
      'playlist_provider': null,
      'enabled_features': ['items'],
      'invitation_deadline': null,
    });

    expect(event.shortAddressSummary.primary, 'Clermont-Ferrand');
    expect(event.shortAddressSummary.secondary, 'Auvergne-Rhône-Alpes');
    expect(event.shortAddressSummary.relation, EventAddressRelation.region);
  });

  test(
    'shortAddressSummary keeps the region for a city-only address with one extra component',
    () {
      final event = EventModel.fromJson({
        'event_id': 9,
        'name_event': 'Walk',
        'description': 'Center',
        'date_event': '2030-06-21',
        'start_time': '20:00:00',
        'address': 'Paris, Île-de-France, France',
        'latitude': 48.8566,
        'longitude': 2.3522,
        'payment_provider_id': null,
        'payment_identifier': null,
        'payment_requested_amount': null,
        'payment_per_person': false,
        'owner_email': 'owner@example.com',
        'playlist_url': null,
        'playlist_provider': null,
        'enabled_features': ['items'],
        'invitation_deadline': null,
      });

      expect(event.shortAddressSummary.primary, 'Paris');
      expect(event.shortAddressSummary.secondary, 'Île-de-France');
      expect(event.shortAddressSummary.relation, EventAddressRelation.region);
    },
  );

  test('shortAddressSummary keeps venue when it appears before the street', () {
    final event = EventModel.fromJson({
      'event_id': 7,
      'name_event': 'Concert',
      'description': 'Live',
      'date_event': '2030-06-21',
      'start_time': '20:00:00',
      'address':
          'Le Modern, Rue du Postillon, Moulin des Filoirs, Issoire, Puy-de-Dôme, Auvergne-Rhône-Alpes, France métropolitaine, 63500, France',
      'latitude': 45.543,
      'longitude': 3.249,
      'payment_provider_id': null,
      'payment_identifier': null,
      'payment_requested_amount': null,
      'payment_per_person': false,
      'owner_email': 'owner@example.com',
      'playlist_url': null,
      'playlist_provider': null,
      'enabled_features': ['items'],
      'invitation_deadline': null,
    });

    expect(event.shortAddressSummary.primary, 'Le Modern, Rue du Postillon');
    expect(event.shortAddressSummary.secondary, 'Issoire');
    expect(event.shortAddressSummary.relation, EventAddressRelation.locality);
  });

  test(
    'shortAddressSummary keeps the city when a street address has no postal code',
    () {
      final event = EventModel.fromJson({
        'event_id': 8,
        'name_event': 'Meeting',
        'description': 'Office',
        'date_event': '2030-06-21',
        'start_time': '20:00:00',
        'address': '10 Downing Street, London, England, United Kingdom',
        'latitude': 51.5034,
        'longitude': -0.1276,
        'payment_provider_id': null,
        'payment_identifier': null,
        'payment_requested_amount': null,
        'payment_per_person': false,
        'owner_email': 'owner@example.com',
        'playlist_url': null,
        'playlist_provider': null,
        'enabled_features': ['items'],
        'invitation_deadline': null,
      });

      expect(event.shortAddressSummary.primary, '10 Downing Street');
      expect(event.shortAddressSummary.secondary, 'London');
      expect(event.shortAddressSummary.relation, EventAddressRelation.locality);
    },
  );

  test('address connectors are localized', () {
    final fr = lookupS(const Locale('fr'));
    final en = lookupS(const Locale('en'));

    expect(
      fr.addressWithRegion('Clermont-Ferrand', 'Auvergne-Rhône-Alpes'),
      'Clermont-Ferrand en Auvergne-Rhône-Alpes',
    );
    expect(
      en.addressWithLocality('115 Boulevard Lafayette', 'Clermont-Ferrand'),
      '115 Boulevard Lafayette in Clermont-Ferrand',
    );
  });

  test('past events are exposed as finished and read-only', () {
    final event = EventModel.fromJson({
      'event_id': 4,
      'name_event': 'Ancienne soirée',
      'description': 'Déjà passée',
      'date_event': '2020-01-01',
      'start_time': '21:00:00',
      'address': '1 rue du passé',
      'latitude': null,
      'longitude': null,
      'payment_provider_id': null,
      'payment_identifier': null,
      'payment_requested_amount': null,
      'payment_per_person': false,
      'owner_email': 'owner@example.com',
      'playlist_url': null,
      'playlist_provider': null,
      'enabled_features': ['expenses'],
      'invitation_deadline': null,
    });

    expect(event.isFinished, isTrue);
    expect(event.isReadOnly, isTrue);
    expect(event.status, 'finished');
  });
}
