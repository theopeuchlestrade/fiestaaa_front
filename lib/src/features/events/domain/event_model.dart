import 'package:intl/intl.dart';

const String eventFeatureCarpools = 'carpools';
const String eventFeaturePolls = 'polls';
const String eventFeatureItems = 'items';
const String eventFeatureTicketing = 'ticketing';
const String eventFeaturePlaylist = 'playlist';
const String eventFeaturePayment = 'payment';
const String eventFeatureExpenses = 'expenses';
const List<String> defaultEventFeatures = <String>[
  eventFeatureCarpools,
  eventFeaturePolls,
  eventFeatureItems,
];

enum EventAddressRelation { none, locality, region }

class EventAddressSummary {
  const EventAddressSummary({
    required this.primary,
    this.secondary,
    this.relation = EventAddressRelation.none,
  });

  final String primary;
  final String? secondary;
  final EventAddressRelation relation;
}

class EventModel {
  EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.paymentProviderId,
    required this.paymentIdentifier,
    required this.paymentRequestedAmount,
    required this.paymentPerPerson,
    required this.ownerEmail,
    required this.playlistUrl,
    required this.playlistProvider,
    required this.enabledFeatures,
    this.invitationDeadline,
  });

  final int id;
  final String name;
  final String description;
  final DateTime date;
  final Duration startTime;
  final DateTime? endDate;
  final Duration? endTime;
  final String address;
  final double? latitude;
  final double? longitude;
  final int? paymentProviderId;
  final String? paymentIdentifier;
  final double? paymentRequestedAmount;
  final bool paymentPerPerson;
  final String ownerEmail;
  final String? playlistUrl;
  final String? playlistProvider;
  final List<String> enabledFeatures;
  final DateTime? invitationDeadline;

  DateTime get startDateTime =>
      DateTime(date.year, date.month, date.day).add(startTime);

  DateTime? get endDateTime {
    if (endDate == null || endTime == null) return null;
    return DateTime(endDate!.year, endDate!.month, endDate!.day).add(endTime!);
  }

  bool get hasEndDateTime => endDate != null && endTime != null;

  bool get isFinished {
    final now = DateTime.now();
    final computedEnd = endDateTime;
    if (computedEnd != null) {
      return now.isAfter(computedEnd);
    }
    if (now.isBefore(startDateTime)) {
      return false;
    }
    return !_isSameDay(now, date);
  }

  bool get isOngoing {
    if (isFinished) return false;
    final now = DateTime.now();
    if (now.isBefore(startDateTime)) return false;
    final computedEnd = endDateTime;
    if (computedEnd != null) {
      return !now.isAfter(computedEnd);
    }
    return _isSameDay(now, date);
  }

  bool get isUpcoming => !isFinished && !isOngoing;

  bool get isReadOnly => isFinished;

  String get status {
    if (isFinished) return 'finished';
    if (isOngoing) return 'ongoing';
    return 'upcoming';
  }

  String get formattedDate =>
      DateFormat.yMMMMd('fr_FR').format(date); // locale friendly

  String get formattedTime {
    final hours = startTime.inHours.toString().padLeft(2, '0');
    final minutes = (startTime.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  EventAddressSummary get shortAddressSummary => _formatShortAddress(address);

  String? get formattedEndDate =>
      endDate == null ? null : DateFormat.yMMMMd('fr_FR').format(endDate!);

  String? get formattedEndTime {
    final value = endTime;
    if (value == null) return null;
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String? get formattedInvitationDeadline => invitationDeadline == null
      ? null
      : DateFormat.yMMMMd('fr_FR').format(invitationDeadline!);

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date_event'] as String);
    final startTime = _parseTime(json['start_time'] as String);
    final endDateRaw = json['end_date'] as String?;
    final endTimeRaw = json['end_time'] as String?;
    final paymentProviderId = (json['payment_provider_id'] as num?)?.toInt();
    final paymentIdentifier = json['payment_identifier'] as String?;
    final playlistUrl = json['playlist_url'] as String?;
    final playlistProvider = json['playlist_provider'] as String?;
    return EventModel(
      id: (json['event_id'] as num).toInt(),
      name: json['name_event'] as String,
      description: json['description'] as String,
      date: date,
      startTime: startTime,
      endDate: endDateRaw == null || endDateRaw.isEmpty
          ? null
          : DateTime.parse(endDateRaw),
      endTime: endTimeRaw == null || endTimeRaw.isEmpty
          ? null
          : _parseTime(endTimeRaw),
      address: json['address'] as String,
      latitude: _parseNullableDouble(json['latitude']),
      longitude: _parseNullableDouble(json['longitude']),
      paymentProviderId: paymentProviderId,
      paymentIdentifier: paymentIdentifier,
      paymentRequestedAmount: (json['payment_requested_amount'] as num?)
          ?.toDouble(),
      paymentPerPerson: (json['payment_per_person'] as bool?) ?? false,
      ownerEmail: json['owner_email'] as String? ?? '',
      playlistUrl: playlistUrl,
      playlistProvider: playlistProvider,
      enabledFeatures: _parseEnabledFeatures(
        json['enabled_features'],
        paymentProviderId: paymentProviderId,
        paymentIdentifier: paymentIdentifier,
        playlistProvider: playlistProvider,
        playlistUrl: playlistUrl,
      ),
      invitationDeadline:
          (json['invitation_deadline'] as String?)?.isEmpty ?? true
          ? null
          : DateTime.parse(json['invitation_deadline'] as String),
    );
  }

  static Duration _parseTime(String value) {
    final parts = value.split(':').map(int.parse).toList();
    final hours = parts.isNotEmpty ? parts[0] : 0;
    final minutes = parts.length > 1 ? parts[1] : 0;
    return Duration(hours: hours, minutes: minutes);
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static EventAddressSummary _formatShortAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const EventAddressSummary(primary: '');
    }

    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      return EventAddressSummary(primary: trimmed);
    }

    final streetPartIndexes = _findStreetPartIndexes(parts);
    final primary = _joinParts(parts, streetPartIndexes);
    final secondary = _extractSecondaryPart(parts, streetPartIndexes);

    if (secondary == null || secondary.value == primary) {
      return EventAddressSummary(primary: primary);
    }
    return EventAddressSummary(
      primary: primary,
      secondary: secondary.value,
      relation: secondary.relation,
    );
  }

  static Set<int> _findStreetPartIndexes(List<String> parts) {
    final streetIndex = parts.indexWhere(_looksLikeStreetPart);
    if (streetIndex >= 0) {
      final indexes = <int>{streetIndex};
      if (streetIndex > 0 && _looksLikeHouseNumber(parts[streetIndex - 1])) {
        indexes.add(streetIndex - 1);
      }
      indexes.addAll(_findVenueIndexes(parts, streetIndex));
      if (indexes.isNotEmpty) {
        return indexes;
      }
    }

    if (parts.length > 1 &&
        _looksLikeHouseNumber(parts.first) &&
        !_looksLikePostalCode(parts[1]) &&
        !_looksLikeCountryOrTerritory(parts[1]) &&
        (_looksLikeStreetPart(parts[1]) || parts.length > 3)) {
      return {0, 1};
    }

    return {0};
  }

  static Set<int> _findVenueIndexes(List<String> parts, int streetIndex) {
    final indexes = <int>{};
    for (var i = 0; i < streetIndex; i++) {
      final part = parts[i];
      if (_looksLikeHouseNumber(part) ||
          _looksLikePostalCode(part) ||
          _looksLikeCountryOrTerritory(part)) {
        continue;
      }
      indexes.add(i);
    }
    return indexes;
  }

  static _AddressSecondaryPart? _extractSecondaryPart(
    List<String> parts,
    Set<int> streetPartIndexes,
  ) {
    final hasStreet = streetPartIndexes.any(
      (index) => _looksLikeStreetPart(parts[index]),
    );
    if (hasStreet) {
      return _extractLocalityPart(parts, streetPartIndexes);
    }
    return _extractNoStreetPart(parts, streetPartIndexes);
  }

  static _AddressSecondaryPart? _extractLocalityPart(
    List<String> parts,
    Set<int> streetPartIndexes,
  ) {
    final postalIndex = parts.indexWhere(_looksLikePostalCode);
    final streetEnd = streetPartIndexes.reduce((a, b) => a > b ? a : b);
    final upperBound = postalIndex >= 0 ? postalIndex : parts.length;
    final candidates = <String>[];

    for (var i = streetEnd + 1; i < upperBound; i++) {
      final part = parts[i];
      if (_looksLikePostalCode(part) || _looksLikeCountryOrTerritory(part)) {
        continue;
      }
      candidates.add(part);
    }

    if (candidates.isEmpty) return null;
    if (candidates.length >= 3) {
      return _AddressSecondaryPart(
        value: candidates[candidates.length - 3],
        relation: EventAddressRelation.locality,
      );
    }
    if (candidates.length == 2) {
      return _AddressSecondaryPart(
        value: candidates.first,
        relation: EventAddressRelation.locality,
      );
    }
    return _AddressSecondaryPart(
      value: candidates.last,
      relation: EventAddressRelation.locality,
    );
  }

  static _AddressSecondaryPart? _extractNoStreetPart(
    List<String> parts,
    Set<int> streetPartIndexes,
  ) {
    final postalIndex = parts.indexWhere(_looksLikePostalCode);
    final primaryEnd = streetPartIndexes.reduce((a, b) => a > b ? a : b);
    final upperBound = postalIndex >= 0 ? postalIndex : parts.length;
    final candidates = <String>[];

    for (var i = primaryEnd + 1; i < upperBound; i++) {
      final part = parts[i];
      if (_looksLikePostalCode(part) || _looksLikeCountryOrTerritory(part)) {
        continue;
      }
      candidates.add(part);
    }

    if (candidates.isEmpty) {
      return null;
    }
    if (candidates.length <= 2) {
      return _AddressSecondaryPart(
        value: candidates.last,
        relation: EventAddressRelation.region,
      );
    }
    return _AddressSecondaryPart(
      value: candidates[candidates.length - 3],
      relation: EventAddressRelation.locality,
    );
  }

  static String _joinParts(List<String> parts, Set<int> indexes) {
    final sortedIndexes = indexes.toList()..sort();
    if (sortedIndexes.isEmpty) return '';

    final buffer = StringBuffer(parts[sortedIndexes.first]);
    for (var i = 1; i < sortedIndexes.length; i++) {
      final previous = parts[sortedIndexes[i - 1]];
      final current = parts[sortedIndexes[i]];
      buffer
        ..write(_primaryPartSeparator(previous, current))
        ..write(current);
    }
    return buffer.toString();
  }

  static String _primaryPartSeparator(String previous, String current) {
    final previousIsStreetBlock =
        _looksLikeHouseNumber(previous) || _looksLikeStreetPart(previous);
    final currentIsStreetBlock =
        _looksLikeHouseNumber(current) || _looksLikeStreetPart(current);
    if (previousIsStreetBlock && currentIsStreetBlock) {
      return ' ';
    }
    return ', ';
  }

  static bool _looksLikeStreetPart(String value) {
    final normalized = value.toLowerCase();
    const streetKeywords = <String>[
      'rue',
      'avenue',
      'av.',
      'boulevard',
      'bd',
      'chemin',
      'impasse',
      'route',
      'allee',
      'allée',
      'place',
      'quai',
      'cours',
      'square',
      'passage',
      'sentier',
      'montee',
      'montée',
      'faubourg',
      'promenade',
      'esplanade',
      'voie',
      'villa',
      'street',
      'st.',
      'road',
      'rd.',
      'drive',
      'dr.',
      'lane',
      'court',
      'way',
      'parkway',
      'highway',
      'trail',
      'terrace',
    ];

    for (final keyword in streetKeywords) {
      if (normalized == keyword ||
          normalized.startsWith('$keyword ') ||
          normalized.contains(' $keyword ') ||
          normalized.endsWith(' $keyword')) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikeHouseNumber(String value) => RegExp(
    r'^\d+(?:\s*[-/]\s*\d+)?(?:\s*(?:bis|ter|quater|[a-z]))?$',
    caseSensitive: false,
  ).hasMatch(value.trim());

  static bool _looksLikePostalCode(String value) =>
      RegExp(r'^\d{4,6}(?:-\d{4})?$').hasMatch(value.trim());

  static bool _looksLikeCountryOrTerritory(String value) {
    final normalized = value.toLowerCase();
    const countryOrTerritoryNames = <String>{
      'france',
      'france métropolitaine',
      'france metropolitaine',
      'metropolitan france',
      'united states',
      'united states of america',
      'usa',
      'united kingdom',
      'uk',
    };
    return countryOrTerritoryNames.contains(normalized);
  }

  static List<String> _parseEnabledFeatures(
    dynamic value, {
    required int? paymentProviderId,
    required String? paymentIdentifier,
    required String? playlistProvider,
    required String? playlistUrl,
  }) {
    const allowed = <String>{
      eventFeatureCarpools,
      eventFeaturePolls,
      eventFeatureItems,
      eventFeatureTicketing,
      eventFeaturePlaylist,
      eventFeaturePayment,
      eventFeatureExpenses,
    };

    if (value is List) {
      final result = <String>[];
      final seen = <String>{};
      for (final raw in value) {
        final feature = raw.toString().trim().toLowerCase();
        if (feature.isEmpty || !allowed.contains(feature)) {
          continue;
        }
        if (seen.add(feature)) {
          result.add(feature);
        }
      }
      return result;
    }

    final inferred = List<String>.from(defaultEventFeatures);
    final hasPlaylistData =
        (playlistProvider?.trim().isNotEmpty ?? false) &&
        (playlistUrl?.trim().isNotEmpty ?? false);
    final hasPaymentData =
        paymentProviderId != null &&
        (paymentIdentifier?.trim().isNotEmpty ?? false);
    if (hasPlaylistData) {
      inferred.add(eventFeaturePlaylist);
    }
    if (hasPaymentData) {
      inferred.add(eventFeaturePayment);
    }
    return inferred;
  }
}

class _AddressSecondaryPart {
  const _AddressSecondaryPart({required this.value, required this.relation});

  final String value;
  final EventAddressRelation relation;
}

class EventPayload {
  EventPayload({
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
    this.endDate,
    this.endTime,
    required this.address,
    this.invitationDeadline,
    this.latitude,
    this.longitude,
    this.paymentProviderId,
    this.paymentIdentifier,
    this.paymentRequestedAmount,
    this.paymentPerPerson = false,
    this.playlistUrl,
    this.playlistProvider,
    this.enabledFeatures,
  });

  final String name;
  final String description;
  final DateTime date;
  final Duration startTime;
  final DateTime? endDate;
  final Duration? endTime;
  final String address;
  final DateTime? invitationDeadline;
  final double? latitude;
  final double? longitude;
  final int? paymentProviderId;
  final String? paymentIdentifier;
  final double? paymentRequestedAmount;
  final bool paymentPerPerson;
  final String? playlistUrl;
  final String? playlistProvider;
  final List<String>? enabledFeatures;

  Map<String, dynamic> toJson() {
    return {
      'name_event': name,
      'description': description,
      'date_event': DateFormat('yyyy-MM-dd').format(date),
      'start_time': _formatDuration(startTime),
      'end_date': endDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(endDate!),
      'end_time': endTime == null ? null : _formatDuration(endTime!),
      'address': address,
      'invitation_deadline': invitationDeadline == null
          ? null
          : DateFormat('yyyy-MM-dd').format(invitationDeadline!),
      'latitude': latitude,
      'longitude': longitude,
      'payment_provider_id': paymentProviderId,
      'payment_identifier': paymentIdentifier,
      'payment_requested_amount': paymentRequestedAmount,
      'payment_per_person': paymentPerPerson,
      'playlist_url': playlistUrl,
      'playlist_provider': playlistProvider,
      if (enabledFeatures != null) 'enabled_features': enabledFeatures,
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }
}
