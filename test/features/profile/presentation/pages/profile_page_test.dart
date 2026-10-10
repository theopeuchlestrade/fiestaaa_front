import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends ProfileApi {
  @override
  Future<ProfileInfo> fetchProfile(String token) async => ProfileInfo(
    email: 'demo@example.invalid',
    handle: 'demo',
    expiration: DateTime(2099),
  );
  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'profile edits are explicit and cancel discards unsaved handle input',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: ProfilePage(
              session: SessionData(
                token: 'test',
                email: 'demo@example.invalid',
              ),
              onLogout: () {},
              api: _Api(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@demo'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'unsaved');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'demo',
      );
      expect(find.text('@demo'), findsOneWidget);
    },
  );
}
