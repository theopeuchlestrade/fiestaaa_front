import 'package:fiestaaa_front/src/core/map_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved coordinates take precedence over ambiguous address text', () {
    final uri = mapDestinationUri(
      MapProvider.google,
      address: 'Paris',
      latitude: 48.85,
      longitude: 2.35,
    );
    expect(uri.queryParameters['query'], '48.85,2.35');
    expect(uri.queryParameters['api'], '1');
  });
  test('all providers accept addresses without a saved pin', () {
    const address = '12 rue de l’Église & place A, Lyon';
    for (final provider in MapProvider.values) {
      final uri = mapDestinationUri(provider, address: address);
      expect(uri.scheme, 'https');
      expect(uri.queryParameters.values, contains(address));
      expect(uri.queryParameters.containsKey('ll'), isFalse);
    }
  });
  test('invalid coordinates fall back to the address', () {
    final uri = mapDestinationUri(
      MapProvider.waze,
      address: 'Paris',
      latitude: double.nan,
      longitude: 2.35,
    );
    expect(uri.queryParameters['q'], 'Paris');
    expect(uri.queryParameters.containsKey('ll'), isFalse);
  });
  test('Apple and OSM preserve the saved pin without starting navigation', () {
    final apple = mapDestinationUri(
      MapProvider.apple,
      address: 'Lieu',
      latitude: 48.85,
      longitude: 2.35,
    );
    expect(apple.queryParameters['ll'], '48.85,2.35');
    final osm = mapDestinationUri(
      MapProvider.osm,
      address: 'Lieu',
      latitude: 48.85,
      longitude: 2.35,
    );
    expect(osm.fragment, 'map=17/48.85/2.35');
    final waze = mapDestinationUri(
      MapProvider.waze,
      address: 'Lieu',
      latitude: 48.85,
      longitude: 2.35,
    );
    expect(waze.queryParameters['ll'], '48.85,2.35');
    expect(waze.queryParameters.containsKey('navigate'), isFalse);
  });
}
