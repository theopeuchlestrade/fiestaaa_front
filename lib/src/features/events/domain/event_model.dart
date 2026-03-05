import 'package:intl/intl.dart';

const String eventFeatureCarpools = 'carpools';
const String eventFeaturePolls = 'polls';
const String eventFeatureItems = 'items';
const String eventFeaturePlaylist = 'playlist';
const String eventFeaturePayment = 'payment';
const List<String> defaultEventFeatures = <String>[
  eventFeatureCarpools,
  eventFeaturePolls,
  eventFeatureItems,
];

class EventModel {
  EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
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

  String get formattedDate =>
      DateFormat.yMMMMd('fr_FR').format(date); // locale friendly

  String get formattedTime {
    final hours = startTime.inHours.toString().padLeft(2, '0');
    final minutes = (startTime.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String? get formattedInvitationDeadline => invitationDeadline == null
      ? null
      : DateFormat.yMMMMd('fr_FR').format(invitationDeadline!);

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date_event'] as String);
    final startTime = _parseTime(json['start_time'] as String);
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
      eventFeaturePlaylist,
      eventFeaturePayment,
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

class EventPayload {
  EventPayload({
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
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
