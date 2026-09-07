import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fiestaaa_front/src/features/events/presentation/event_form_session.dart';

Map<String, dynamic> fields(String name) => {
  'name': name,
  'description': 'Dinner',
  'address': 'Paris',
  'paymentIdentifier': '',
  'paymentAmount': '',
  'playlistUrl': '',
  'date': '2099-01-01T00:00:00.000',
  'timezone': 'Europe/Paris',
  'time': '20:0',
  'hasEnd': false,
  'endDate': null,
  'endTime': null,
  'deadline': null,
  'provider': null,
  'perPerson': false,
  'playlistProvider': null,
  'features': <String>[],
};

class FailingStore extends EventDraftStore {
  @override
  Future<void> write(String account, Map<String, dynamic> fields) async =>
      throw StateError('full');
}

class SlowStore extends EventDraftStore {
  final first = Completer<void>();
  final saved = <String>[];
  @override
  Future<void> write(String account, Map<String, dynamic> fields) async {
    if (saved.isEmpty) await first.future;
    saved.add(fields['name'] as String);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'draft survives a new session, remains isolated and clears on success',
    () async {
      const store = EventDraftStore();
      final session = EventFormSession(account: 'Me@Example.com', persist: true)
        ..start(fields(''));
      session.changed(fields('Party'));
      expect(await session.flush(), isTrue);
      session.dispose();
      expect((await store.read('me@example.com'))?['name'], 'Party');
      expect(await store.read('other@example.com'), isNull);
      final resumed = EventFormSession(account: 'me@example.com', persist: true)
        ..start((await store.read('me@example.com'))!, restored: true);
      await resumed.complete();
      expect(await store.read('me@example.com'), isNull);
      resumed.dispose();
    },
  );
  test('failed save keeps changes dirty; edit never writes a draft', () async {
    final session = EventFormSession(
      account: 'me',
      persist: true,
      store: FailingStore(),
    )..start(fields(''));
    session.changed(fields('Party'));
    expect(await session.flush(), isFalse);
    expect(session.failed, isTrue);
    expect(session.dirty, isTrue);
    session.dispose();
    final edit = EventFormSession(account: 'me', persist: false)
      ..start(fields('Old'));
    edit.changed(fields('New'));
    expect(await edit.flush(), isFalse);
    expect(await const EventDraftStore().read('me'), isNull);
    edit.changed(fields('Old'));
    expect(edit.dirty, isFalse);
    edit.dispose();
  });
  test('queued saves do not mark a newer edit as saved', () async {
    final store = SlowStore();
    final session = EventFormSession(account: 'me', persist: true, store: store)
      ..start(fields(''));
    session.changed(fields('First'));
    final first = session.flush();
    session.changed(fields('Second'));
    final second = session.flush();
    store.first.complete();
    await first;
    await second;
    expect(store.saved, ['First', 'Second']);
    expect(session.dirty, isFalse);
    session.dispose();
  });
  test('invalid or incompatible local drafts are rejected', () async {
    const store = EventDraftStore();
    final prefs = await SharedPreferences.getInstance();
    for (final raw in [
      '{',
      jsonEncode({'version': 2, 'fields': fields('Party')}),
      jsonEncode({'version': 1, 'fields': {}}),
    ]) {
      await prefs.setString(store.key('me'), raw);
      await expectLater(store.read('me'), throwsA(isA<FormatException>()));
    }
  });
  testWidgets('autosave is debounced by 500 milliseconds', (tester) async {
    final store = SlowStore()..first.complete();
    final session = EventFormSession(account: 'me', persist: true, store: store)
      ..start(fields(''));
    session.changed(fields('A'));
    await tester.pump(const Duration(milliseconds: 300));
    session.changed(fields('AB'));
    await tester.pump(const Duration(milliseconds: 499));
    expect(store.saved, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(store.saved, ['AB']);
    session.dispose();
  });
}
