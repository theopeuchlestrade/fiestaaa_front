enum MapProvider { google, apple, waze, osm }

/// Use the saved pin when available, otherwise search the original address.
/// HTTPS links support the provider app and its fallback when it is absent.
Uri mapDestinationUri(
  MapProvider provider, {
  required String address,
  double? latitude,
  double? longitude,
}) {
  final hasCoordinates =
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  final coordinates = '$latitude,$longitude';
  final query = hasCoordinates ? coordinates : address.trim();
  return switch (provider) {
    MapProvider.google => Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    }),
    MapProvider.apple => Uri.https('maps.apple.com', '/', {
      'q': address.trim(),
      if (hasCoordinates) 'll': coordinates,
    }),
    MapProvider.waze => Uri.https('waze.com', '/ul', {
      if (hasCoordinates) 'll': coordinates else 'q': query,
      'zoom': '17',
    }),
    MapProvider.osm =>
      hasCoordinates
          ? Uri.https('www.openstreetmap.org', '/', {
              'mlat': '$latitude',
              'mlon': '$longitude',
            }).replace(fragment: 'map=17/$latitude/$longitude')
          : Uri.https('www.openstreetmap.org', '/search', {'query': query}),
  };
}
