class SessionData {
  SessionData({
    required this.token,
    required this.email,
    this.handle,
    this.publicId,
  });

  final String token;
  final String email;
  final String? handle;
  final String? publicId;

  SessionData copyWith({
    String? token,
    String? email,
    String? handle,
    String? publicId,
  }) {
    return SessionData(
      token: token ?? this.token,
      email: email ?? this.email,
      handle: handle ?? this.handle,
      publicId: publicId ?? this.publicId,
    );
  }
}
