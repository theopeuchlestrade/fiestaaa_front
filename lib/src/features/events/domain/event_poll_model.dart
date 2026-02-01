class PollOptionVoterModel {
  PollOptionVoterModel({required this.email, this.handle, this.avatarUrl});

  final String email;
  final String? handle;
  final String? avatarUrl;

  factory PollOptionVoterModel.fromJson(Map<String, dynamic> json) {
    return PollOptionVoterModel(
      email: json['email'] as String,
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class PollOptionModel {
  PollOptionModel({
    required this.id,
    required this.label,
    required this.voteCount,
    required this.voters,
  });

  final int id;
  final String label;
  final int voteCount;
  final List<PollOptionVoterModel> voters;

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    final votersJson = json['voters'] as List<dynamic>? ?? const [];
    return PollOptionModel(
      id: (json['option_id'] as num).toInt(),
      label: json['label'] as String,
      voteCount: (json['vote_count'] as num).toInt(),
      voters: votersJson
          .map((v) => PollOptionVoterModel.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PollModel {
  PollModel({
    required this.id,
    required this.eventId,
    required this.question,
    required this.allowMultiple,
    required this.expiresAt,
    required this.createdAt,
    required this.createdByEmail,
    required this.options,
    required this.myVotes,
    required this.totalVotes,
    required this.hasExpired,
  });

  final int id;
  final int eventId;
  final String question;
  final bool allowMultiple;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? createdByEmail;
  final List<PollOptionModel> options;
  final List<int> myVotes;
  final int totalVotes;
  final bool hasExpired;

  bool get isExpired => hasExpired || expiresAt.isBefore(DateTime.now());

  int get maxVotes => options.fold<int>(
    0,
    (currentMax, option) =>
        option.voteCount > currentMax ? option.voteCount : currentMax,
  );

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'] as List<dynamic>? ?? const [];
    final myVotesJson = json['my_votes'] as List<dynamic>? ?? const [];
    return PollModel(
      id: (json['poll_id'] as num).toInt(),
      eventId: (json['event_id'] as num).toInt(),
      question: json['question'] as String,
      allowMultiple: json['allow_multiple'] as bool? ?? true,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdByEmail: json['created_by_email'] as String?,
      options: optionsJson
          .map((o) => PollOptionModel.fromJson(o as Map<String, dynamic>))
          .toList(),
      myVotes: myVotesJson.map((v) => (v as num).toInt()).toList(),
      totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
      hasExpired: json['has_expired'] as bool? ?? false,
    );
  }
}
