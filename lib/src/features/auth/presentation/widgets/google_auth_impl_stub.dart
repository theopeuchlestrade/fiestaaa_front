import 'package:fiestaaa_front/src/features/auth/presentation/widgets/google_auth_helper.dart';

class GoogleAuthImpl extends GoogleAuthHelper {
  @override
  Future<GoogleAuthResult?> signIn({
    required String? clientId,
    required List<String> scopes,
  }) async {
    throw UnimplementedError('This helper is designed for Web usage override.');
  }
}

GoogleAuthHelper get googleAuthHelper => GoogleAuthImpl();
