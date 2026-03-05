import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save and load round-trip a complete session', () async {
    final session = SessionData(
      token: 'token-123',
      email: 'me@example.com',
      handle: 'fiestaaa',
    );

    await SessionStorage.save(session);
    final restored = await SessionStorage.load();

    expect(restored?.token, session.token);
    expect(restored?.email, session.email);
    expect(restored?.handle, session.handle);
  });

  test('save removes an old persisted handle when session has none', () async {
    SharedPreferences.setMockInitialValues({'fiestaaa_handle': 'old-handle'});

    await SessionStorage.save(
      SessionData(token: 'token-123', email: 'me@example.com'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fiestaaa_handle'), isNull);
  });

  test('load returns null when token or email is missing', () async {
    SharedPreferences.setMockInitialValues({'fiestaaa_token': 'token-only'});

    expect(await SessionStorage.load(), isNull);
  });

  test('clear removes every persisted session field', () async {
    SharedPreferences.setMockInitialValues({
      'fiestaaa_token': 'token-123',
      'fiestaaa_email': 'me@example.com',
      'fiestaaa_handle': 'fiestaaa',
    });

    await SessionStorage.clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fiestaaa_token'), isNull);
    expect(prefs.getString('fiestaaa_email'), isNull);
    expect(prefs.getString('fiestaaa_handle'), isNull);
  });
}
