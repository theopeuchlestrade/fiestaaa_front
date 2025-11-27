class SessionData {
  SessionData({
    required this.token,
    required this.email,
    this.handle,
  });

  final String token;
  final String email;
  final String? handle;

  SessionData copyWith({
    String? token,
    String? email,
    String? handle,
  }) {
    return SessionData(
      token: token ?? this.token,
      email: email ?? this.email,
      handle: handle ?? this.handle,
    );
  }
}
