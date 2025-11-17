class ProfileInfo {
  ProfileInfo({required this.email, required this.expiration});

  final String email;
  final DateTime expiration;

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    final expTs = json['exp'] as int;
    return ProfileInfo(
      email: json['email'] as String,
      expiration: DateTime.fromMillisecondsSinceEpoch(expTs * 1000, isUtc: true)
          .toLocal(),
    );
  }
}
