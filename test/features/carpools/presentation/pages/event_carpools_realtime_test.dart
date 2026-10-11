import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/carpools/data/carpools_api.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/pages/event_carpools_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends CarpoolsApi {
  int reads = 0;
  List<CarpoolModel> rides = [];
  @override
  Future<List<CarpoolModel>> fetchEventCarpools({
    required String token,
    required int eventId,
    String? sortBy,
  }) async {
    reads++;
    return rides;
  }
}

void main() {
  testWidgets('current ride is first and creation is hidden for its driver', (
    tester,
  ) async {
    final api = _Api();
    CarpoolModel ride(int id, String handle) => CarpoolModel(
      carpoolId: id,
      eventId: 1,
      driverId: id,
      driverHandle: handle,
      origin: 'Station $id',
      departAt: DateTime(2099, 7, 1, 18),
      seatsTotal: 3,
      seatsTaken: 0,
      createdAt: DateTime(2099),
      updatedAt: DateTime(2099),
      passengers: [],
    );
    api.rides = [ride(1, 'other'), ride(2, 'creator'), ride(3, 'third')];
    final messages = StreamController<Map<String, dynamic>>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: EventCarpoolsPage(
          api: api,
          eventId: 1,
          eventName: 'Test event',
          eventDate: DateTime(2099, 7, 1),
          session: SessionData(
            token: 'test',
            email: 'creator@example.invalid',
            handle: 'creator',
          ),
          isOwner: true,
          hasAcceptedInvitation: true,
          eventReadOnly: false,
          realtimeStream: messages.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final origins = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => text?.startsWith('Station ') ?? false)
        .toList();
    expect(origins, ['Station 2', 'Station 1', 'Station 3']);
    expect(find.text('Your ride'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Propose a carpool'),
      findsNothing,
    );
    expect(find.text('Join this ride'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await messages.close();
  });

  testWidgets('server carpool mutations refresh the shared event module', (
    tester,
  ) async {
    final messages = StreamController<Map<String, dynamic>>.broadcast();
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: EventCarpoolsPage(
          api: api,
          eventId: 1,
          eventName: 'Test event',
          eventDate: DateTime(2027, 7, 1),
          session: SessionData(token: 'test', email: 'owner@example.invalid'),
          isOwner: true,
          hasAcceptedInvitation: true,
          eventReadOnly: false,
          realtimeStream: messages.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.reads, 1);
    for (final type in [
      'carpool_created',
      'carpool_updated',
      'carpool_deleted',
      'carpool_joined',
      'carpool_left',
      'event.carpools.changed',
      'realtime.ready',
    ]) {
      final before = api.reads;
      messages.add({'type': type, 'carpool_id': 4});
      await tester.pumpAndSettle();
      expect(api.reads, before + 1, reason: type);
    }
    final before = api.reads;
    messages.add({'type': 'carpool_joined', 'event_id': 2});
    messages.add({'type': 'event.polls.changed', 'event_id': 1});
    await tester.pumpAndSettle();
    expect(api.reads, before);
    await tester.pumpWidget(const SizedBox());
    await messages.close();
  });
}
