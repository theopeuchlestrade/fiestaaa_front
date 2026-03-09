import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await SessionStorage.clear();
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
    await SessionStorage.save(
      SessionData(
        token: 'token-legacy',
        email: 'legacy@example.com',
        handle: 'old-handle',
      ),
    );

    await SessionStorage.save(
      SessionData(token: 'token-123', email: 'me@example.com'),
    );

    final restored = await SessionStorage.load();
    expect(restored?.handle, isNull);
  });

  test('load returns null when token or email is missing', () async {
    expect(await SessionStorage.load(), isNull);
  });

  test('clear removes every persisted session field', () async {
    await SessionStorage.save(
      SessionData(
        token: 'token-123',
        email: 'me@example.com',
        handle: 'fiestaaa',
      ),
    );

    await SessionStorage.clear();

    expect(await SessionStorage.load(), isNull);
  });
}
