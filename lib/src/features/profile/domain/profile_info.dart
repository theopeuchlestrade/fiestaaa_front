class ProfileInfo {
  ProfileInfo({
    required this.email,
    required this.handle,
    required this.expiration,
    this.avatarUrl,
  });

  final String email;
  final String handle;
  final DateTime expiration;
  final String? avatarUrl;

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    final expTs = json['exp'] as int;
    return ProfileInfo(
      email: json['email'] as String,
      handle: json['handle'] as String,
      expiration: DateTime.fromMillisecondsSinceEpoch(
        expTs * 1000,
        isUtc: true,
      ).toLocal(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
