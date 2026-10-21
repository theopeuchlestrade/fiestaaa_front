class SessionData {
  SessionData({
    required this.token,
    required this.email,
    this.handle,
    this.publicId,
    this.refreshToken,
  });

  final String token;
  final String? refreshToken;
  final String email;
  final String? handle;
  final String? publicId;

  SessionData copyWith({
    String? token,
    String? email,
    String? handle,
    String? publicId,
    String? refreshToken,
  }) {
    return SessionData(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      handle: handle ?? this.handle,
      publicId: publicId ?? this.publicId,
    );
  }
}
