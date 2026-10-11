import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/widgets/carpool_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ride = CarpoolModel(
    carpoolId: 1,
    eventId: 1,
    driverId: 1,
    driverHandle: 'driver',
    origin: 'Station',
    departAt: DateTime(2099, 7, 1, 18),
    seatsTotal: 3,
    seatsTaken: 1,
    notes: 'Meet at the south entrance, next to the ticket office.',
    createdAt: DateTime(2099),
    updatedAt: DateTime(2099),
    passengers: [
      CarpoolPassengerModel(
        userId: 2,
        handle: 'guest',
        joinedAt: DateTime(2099),
      ),
    ],
  );
  Future<void> show(WidgetTester tester, CarpoolCard card) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'available ride joins and reveals complete notes and passengers',
    (tester) async {
      var joined = false;
      await show(
        tester,
        CarpoolCard(
          carpool: ride,
          isDriver: false,
          isPassenger: false,
          onJoin: () => joined = true,
        ),
      );
      expect(find.text('2 seats available'), findsOneWidget);
      await tester.tap(find.text('Join this ride'));
      expect(joined, isTrue);
      await tester.tap(find.text('Ride details'));
      await tester.pumpAndSettle();
      expect(find.text(ride.notes!), findsOneWidget);
      expect(find.text('guest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('driver can edit or delete but cannot join', (tester) async {
    var edited = false;
    var deleted = false;
    await show(
      tester,
      CarpoolCard(
        carpool: ride,
        isDriver: true,
        isPassenger: false,
        onEdit: () => edited = true,
        onDelete: () => deleted = true,
      ),
    );
    expect(find.text('Join this ride'), findsNothing);
    await tester.tap(find.text('Edit'));
    expect(edited, isTrue);
    await tester.tap(find.byTooltip('Ride actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    expect(deleted, isTrue);
  });
  testWidgets('passenger can leave without a join action', (tester) async {
    var left = false;
    await show(
      tester,
      CarpoolCard(
        carpool: ride,
        isDriver: false,
        isPassenger: true,
        onLeave: () => left = true,
      ),
    );
    expect(find.text('Join this ride'), findsNothing);
    await tester.tap(find.text('Leave'));
    expect(left, isTrue);
  });
  testWidgets('restriction remains visible and prevents joining', (
    tester,
  ) async {
    await show(
      tester,
      CarpoolCard(
        carpool: ride,
        isDriver: false,
        isPassenger: false,
        unavailableReason: 'Accept the invitation first',
      ),
    );
    expect(find.text('Accept the invitation first'), findsOneWidget);
    expect(find.text('Join this ride'), findsNothing);
  });
}
