import 'dart:async';
import 'dart:convert';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/my_qr_code_page.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/widgets/checkin_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget app() => const MaterialApp(
  locale: Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: MyQRCodePage(
    eventId: 7,
    eventName: 'Fictional evening',
    token: 'fixture',
  ),
);
String ticket(String token, DateTime expiry) => jsonEncode({
  'qr_token': token,
  'event_id': 7,
  'generated_at': DateTime.now().toUtc().toIso8601String(),
  'expires_at': expiry.toUtc().toIso8601String(),
});
void main() {
  testWidgets(
    'ticket retries failed load then displays only the returned token',
    (tester) async {
      var reads = 0;
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture');
        reads++;
        return reads == 1
            ? http.Response('{}', 503)
            : http.Response(
                ticket(
                  'retried-ticket',
                  DateTime.now().add(const Duration(minutes: 5)),
                ),
                200,
              );
      });
      await runZoned(() async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.byType(TicketCard), findsNothing);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(
          tester.widget<TicketCard>(find.byType(TicketCard)).data.qrToken,
          'retried-ticket',
        );
        await tester.pumpWidget(const SizedBox());
      }, zoneValues: {apiHttpClientFactoryKey: () => client});
    },
  );
  testWidgets(
    'expiry refresh replaces ticket and does not refetch every countdown tick',
    (tester) async {
      var reads = 0;
      final client = MockClient((_) async {
        reads++;
        return http.Response(
          ticket(
            'ticket-$reads',
            DateTime.now().add(Duration(seconds: reads == 1 ? 2 : 300)),
          ),
          200,
        );
      });
      await runZoned(() async {
        await tester.pumpWidget(app());
        await tester.pump();
        expect(reads, 1);
        await tester.pump(const Duration(seconds: 1));
        expect(reads, 1);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(reads, 2);
        expect(
          tester.widget<TicketCard>(find.byType(TicketCard)).data.qrToken,
          'ticket-2',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 6));
        expect(reads, 2);
      }, zoneValues: {apiHttpClientFactoryKey: () => client});
    },
  );
  testWidgets('disposing during initial request never presents a late ticket', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await runZoned(
      () async {
        await tester.pumpWidget(app());
        await tester.pumpWidget(const SizedBox());
        pending.complete(
          http.Response(
            ticket('late', DateTime.now().add(const Duration(minutes: 5))),
            200,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
      zoneValues: {
        apiHttpClientFactoryKey: () => MockClient((_) => pending.future),
      },
    );
  });
}
