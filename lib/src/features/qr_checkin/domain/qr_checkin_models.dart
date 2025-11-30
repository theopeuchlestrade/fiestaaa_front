class QRCodeData {
  final String qrToken;
  final int eventId;
  final DateTime generatedAt;

  const QRCodeData({
    required this.qrToken,
    required this.eventId,
    required this.generatedAt,
  });

  factory QRCodeData.fromJson(Map<String, dynamic> json) {
    return QRCodeData(
      qrToken: json['qr_token'] as String,
      eventId: json['event_id'] as int,
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qr_token': qrToken,
      'event_id': eventId,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

class QRScanResult {
  final bool success;
  final String status;
  final String? userEmail;
  final String? userHandle;
  final String? userAvatarUrl;
  final DateTime? scannedAt;
  final String message;

  const QRScanResult({
    required this.success,
    required this.status,
    this.userEmail,
    this.userHandle,
    this.userAvatarUrl,
    this.scannedAt,
    required this.message,
  });

  factory QRScanResult.fromJson(Map<String, dynamic> json) {
    return QRScanResult(
      success: json['success'] as bool,
      status: json['status'] as String,
      userEmail: json['user_email'] as String?,
      userHandle: json['user_handle'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : null,
      message: json['message'] as String,
    );
  }
}

class QRScanStats {
  final int totalInvited;
  final int totalCheckedIn;
  final int pendingCheckins;

  const QRScanStats({
    required this.totalInvited,
    required this.totalCheckedIn,
    required this.pendingCheckins,
  });

  factory QRScanStats.fromJson(Map<String, dynamic> json) {
    return QRScanStats(
      totalInvited: json['total_invited'] as int,
      totalCheckedIn: json['total_checked_in'] as int,
      pendingCheckins: json['pending_checkins'] as int,
    );
  }

  double get checkInPercentage =>
      totalInvited > 0 ? (totalCheckedIn / totalInvited) * 100 : 0;
}
