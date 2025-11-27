class FriendModel {
  FriendModel({
    required this.email,
    required this.handle,
    required this.since,
  });

  final String email;
  final String handle;
  final DateTime since;

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      email: json['email'] as String,
      handle: json['handle'] as String,
      since: DateTime.parse(json['since'] as String),
    );
  }
}

class FriendSearchResult {
  FriendSearchResult({
    required this.email,
    required this.handle,
  });

  final String email;
  final String handle;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    return FriendSearchResult(
      email: json['email'] as String,
      handle: json['handle'] as String,
    );
  }
}

class FriendRequestModel {
  FriendRequestModel({
    required this.id,
    required this.senderEmail,
    required this.senderHandle,
    required this.receiverEmail,
    required this.receiverHandle,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String senderEmail;
  final String senderHandle;
  final String receiverEmail;
  final String receiverHandle;
  final String status;
  final DateTime createdAt;

  bool isIncoming(String userEmail) =>
      receiverEmail.toLowerCase() == userEmail.toLowerCase();

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: (json['id'] as num).toInt(),
      senderEmail: json['sender_email'] as String,
      senderHandle: json['sender_handle'] as String,
      receiverEmail: json['receiver_email'] as String,
      receiverHandle: json['receiver_handle'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
