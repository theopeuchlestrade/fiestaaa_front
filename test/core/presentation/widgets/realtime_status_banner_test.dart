import 'dart:async';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/realtime_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['fr', 'en']) {
    testWidgets('shows connection loss in $language without removing content', (
      tester,
    ) async {
      final messages = StreamController<Map<String, dynamic>>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: RealtimeStatusBanner(
              stream: messages.stream,
              child: const Center(child: Text('Existing event')),
            ),
          ),
        ),
      );
      messages.add({'type': 'realtime.status', 'state': 'interrupted'});
      await tester.pumpAndSettle();
      expect(find.text('Existing event'), findsOneWidget);
      expect(
        find.text(
          language == 'fr'
              ? 'Connexion interrompue · reconnexion en cours'
              : 'Connection interrupted · reconnecting',
        ),
        findsOneWidget,
      );
      messages.add({'type': 'realtime.status', 'state': 'connected'});
      await tester.pumpAndSettle();
      expect(find.text('Existing event'), findsOneWidget);
      expect(
        find.textContaining(
          language == 'fr' ? 'Connexion interrompue' : 'Connection interrupted',
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(messages.close());
    });
  }
}
