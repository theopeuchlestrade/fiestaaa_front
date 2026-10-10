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
  @override
  Future<List<CarpoolModel>> fetchEventCarpools({
    required String token,
    required int eventId,
    String? sortBy,
  }) async {
    reads++;
    return [];
  }
}

void main() {
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
