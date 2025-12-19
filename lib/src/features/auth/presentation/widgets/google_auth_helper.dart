export 'google_auth_impl_stub.dart'
    if (dart.library.js_interop) 'google_auth_impl_web.dart';

abstract class GoogleAuthHelper {
  Future<GoogleAuthResult?> signIn({
    required String? clientId,
    required List<String> scopes,
  });
}

class GoogleAuthResult {
  final String? idToken;
  final String? accessToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  GoogleAuthResult({
    this.idToken,
    this.accessToken,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}
