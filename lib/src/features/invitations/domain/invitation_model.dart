class InvitationModel {
  InvitationModel({
    required this.eventId,
    required this.email,
    this.handle,
    this.avatarUrl,
    required this.status,
    required this.dateInvi,
    this.eventName,
  });

  final int eventId;
  final String email;
  final String? handle;
  final String? avatarUrl;
  final String status;
  final DateTime dateInvi;
  final String? eventName;

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      eventId: (json['event_id'] as num).toInt(),
      email: json['email'] as String,
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String,
      dateInvi: DateTime.parse(json['date_invi'] as String),
      eventName: json['event_name'] as String?,
    );
  }
}

class InvitationCreationResult {
  InvitationCreationResult.invitation(this.invitation)
      : emailSent = false,
        message = null;

  InvitationCreationResult.emailSent({this.message})
      : invitation = null,
        emailSent = true;

  final InvitationModel? invitation;
  final bool emailSent;
  final String? message;
}
