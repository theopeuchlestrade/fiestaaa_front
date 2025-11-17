class InvitationModel {
  InvitationModel({
    required this.eventId,
    required this.email,
    required this.status,
    required this.dateInvi,
  });

  final int eventId;
  final String email;
  final String status;
  final DateTime dateInvi;

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      eventId: (json['event_id'] as num).toInt(),
      email: json['email'] as String,
      status: json['status'] as String,
      dateInvi: DateTime.parse(json['date_invi'] as String),
    );
  }
}
