import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/invitations/presentation/widgets/invitation_status_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr'), Locale('en')],
    home: Scaffold(body: child),
  );
}

InvitationModel _invitation({
  required String email,
  required String status,
  String? handle,
}) {
  return InvitationModel(
    eventId: 1,
    email: email,
    handle: handle,
    avatarUrl: null,
    status: status,
    dateInvi: DateTime(2030, 7, 1),
    eventName: 'Pool Party',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('renders empty state without count chip', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        const InvitationStatusSection(
          title: 'En attente',
          icon: Icons.schedule,
          accentColor: Colors.orange,
          invitations: [],
          emptyLabel: 'Personne pour le moment',
          ownerEmail: 'owner@example.com',
        ),
      ),
    );

    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Personne pour le moment'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('shows owner badge and delete action only for other invitees', (
    tester,
  ) async {
    InvitationModel? deleted;

    await tester.pumpWidget(
      _buildApp(
        InvitationStatusSection(
          title: 'Invités',
          icon: Icons.people,
          accentColor: Colors.blue,
          invitations: [
            _invitation(
              email: 'owner@example.com',
              status: 'Accepted',
              handle: 'owner',
            ),
            _invitation(
              email: 'guest@example.com',
              status: 'Waiting',
              handle: 'guest',
            ),
          ],
          emptyLabel: 'Aucun invité',
          ownerEmail: 'owner@example.com',
          onDelete: (invitation) => deleted = invitation,
        ),
      ),
    );

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    expect(deleted?.email, 'guest@example.com');
  });
}
