class CarpoolModel {
  final int carpoolId;
  final int eventId;
  final int driverId;
  final String? driverHandle;
  final String? driverAvatarUrl;
  final String origin;
  final double? originLatitude;
  final double? originLongitude;
  final DateTime departAt;
  final int seatsTotal;
  final int seatsTaken;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CarpoolPassengerModel> passengers;

  CarpoolModel({
    required this.carpoolId,
    required this.eventId,
    required this.driverId,
    this.driverHandle,
    this.driverAvatarUrl,
    required this.origin,
    this.originLatitude,
    this.originLongitude,
    required this.departAt,
    required this.seatsTotal,
    required this.seatsTaken,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.passengers,
  });

  factory CarpoolModel.fromJson(Map<String, dynamic> json) {
    return CarpoolModel(
      carpoolId: (json['carpool_id'] as num).toInt(),
      eventId: (json['event_id'] as num).toInt(),
      driverId: (json['driver_id'] as num).toInt(),
      driverHandle: json['driver_handle'] as String?,
      driverAvatarUrl: json['driver_avatar_url'] as String?,
      origin: json['origin'] as String,
      originLatitude: (json['origin_latitude'] as num?)?.toDouble(),
      originLongitude: (json['origin_longitude'] as num?)?.toDouble(),
      departAt: DateTime.parse(json['depart_at'] as String),
      seatsTotal: (json['seats_total'] as num).toInt(),
      seatsTaken: (json['seats_taken'] as num).toInt(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      passengers:
          (json['passengers'] as List<dynamic>?)
              ?.map(
                (e) =>
                    CarpoolPassengerModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  int get seatsAvailable => seatsTotal - seatsTaken;
  bool get isFull => seatsTaken >= seatsTotal;
  bool isDriver(int userId) => driverId == userId;
}

class CarpoolPassengerModel {
  final int userId;
  final String? handle;
  final String? avatarUrl;
  final DateTime joinedAt;

  CarpoolPassengerModel({
    required this.userId,
    this.handle,
    this.avatarUrl,
    required this.joinedAt,
  });

  factory CarpoolPassengerModel.fromJson(Map<String, dynamic> json) {
    return CarpoolPassengerModel(
      userId: (json['user_id'] as num).toInt(),
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

class CarpoolPayload {
  final String origin;
  final double? originLatitude;
  final double? originLongitude;
  final DateTime departAt;
  final int seatsTotal;
  final String? notes;

  CarpoolPayload({
    required this.origin,
    this.originLatitude,
    this.originLongitude,
    required this.departAt,
    required this.seatsTotal,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      if (originLatitude != null) 'origin_latitude': originLatitude,
      if (originLongitude != null) 'origin_longitude': originLongitude,
      'depart_at': departAt.toUtc().toIso8601String(),
      'seats_total': seatsTotal,
      if (notes != null) 'notes': notes,
    };
  }
}

class CarpoolPatchPayload {
  final String? origin;
  final double? originLatitude;
  final double? originLongitude;
  final DateTime? departAt;
  final int? seatsTotal;
  final String? notes;

  CarpoolPatchPayload({
    this.origin,
    this.originLatitude,
    this.originLongitude,
    this.departAt,
    this.seatsTotal,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (origin != null) 'origin': origin,
      if (originLatitude != null) 'origin_latitude': originLatitude,
      if (originLongitude != null) 'origin_longitude': originLongitude,
      if (departAt != null) 'depart_at': departAt!.toUtc().toIso8601String(),
      if (seatsTotal != null) 'seats_total': seatsTotal,
      if (notes != null) 'notes': notes,
    };
  }
}
