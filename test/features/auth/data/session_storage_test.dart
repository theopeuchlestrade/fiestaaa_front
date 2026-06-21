import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SessionStorage.debugResetStorageBackend();
    await SessionStorage.clear();
  });

  tearDown(SessionStorage.debugResetStorageBackend);

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

  test(
    'clear removes fallback data even when secure storage deletes succeed',
    () async {
      final storage = _FakeSessionStorageBackend(failWrites: true);
      SessionStorage.debugSetStorageBackend(storage);

      await SessionStorage.save(
        SessionData(
          token: 'fallback-token',
          email: 'fallback@example.com',
          handle: 'fallback',
        ),
      );

      storage.failReads = true;
      await SessionStorage.clear();

      expect(await SessionStorage.load(), isNull);
    },
  );
}

class _FakeSessionStorageBackend implements SessionStorageBackend {
  _FakeSessionStorageBackend({this.failWrites = false});

  bool failWrites;
  bool failReads = false;
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> write({required String key, String? value}) async {
    if (failWrites) throw StateError('write failed');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({required String key}) async {
    if (failReads) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
