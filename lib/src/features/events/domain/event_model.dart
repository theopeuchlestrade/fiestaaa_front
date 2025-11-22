import 'package:intl/intl.dart';

class EventModel {
  EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
    required this.address,
    required this.paymentProviderId,
    required this.paymentIdentifier,
    required this.paymentRequestedAmount,
    required this.ownerEmail,
  });

  final int id;
  final String name;
  final String description;
  final DateTime date;
  final Duration startTime;
  final String address;
  final int? paymentProviderId;
  final String? paymentIdentifier;
  final double? paymentRequestedAmount;
  final String ownerEmail;

  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
      ).add(startTime);

  String get formattedDate =>
      DateFormat.yMMMMd('fr_FR').format(date); // locale friendly

  String get formattedTime {
    final hours = startTime.inHours.toString().padLeft(2, '0');
    final minutes = (startTime.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date_event'] as String);
    final startTime = _parseTime(json['start_time'] as String);
    return EventModel(
      id: (json['event_id'] as num).toInt(),
      name: json['name_event'] as String,
      description: json['description'] as String,
      date: date,
      startTime: startTime,
      address: json['address'] as String,
      paymentProviderId: (json['payment_provider_id'] as num?)?.toInt(),
      paymentIdentifier: json['payment_identifier'] as String?,
      paymentRequestedAmount:
          (json['payment_requested_amount'] as num?)?.toDouble(),
      ownerEmail: json['owner_email'] as String? ?? '',
    );
  }

  static Duration _parseTime(String value) {
    final parts = value.split(':').map(int.parse).toList();
    final hours = parts.isNotEmpty ? parts[0] : 0;
    final minutes = parts.length > 1 ? parts[1] : 0;
    return Duration(hours: hours, minutes: minutes);
  }
}

class EventPayload {
  EventPayload({
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
    required this.address,
    this.paymentProviderId,
    this.paymentIdentifier,
    this.paymentRequestedAmount,
  });

  final String name;
  final String description;
  final DateTime date;
  final Duration startTime;
  final String address;
  final int? paymentProviderId;
  final String? paymentIdentifier;
  final double? paymentRequestedAmount;

  Map<String, dynamic> toJson() {
    return {
      'name_event': name,
      'description': description,
      'date_event': DateFormat('yyyy-MM-dd').format(date),
      'start_time': _formatDuration(startTime),
      'address': address,
      'payment_provider_id': paymentProviderId,
      'payment_identifier': paymentIdentifier,
      'payment_requested_amount': paymentRequestedAmount,
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }
}
