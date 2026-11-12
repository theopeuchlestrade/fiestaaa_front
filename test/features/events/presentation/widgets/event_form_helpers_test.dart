import 'package:fiestaaa_front/l10n/fiestaaa_localizations.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_form_helpers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('playlist provider field exposes provider choices', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? selectedProvider;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: fiestaaaLocalizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: EventPlaylistSection(
            valueKeyPrefix: 'test',
            enabled: true,
            selectedProvider: null,
            urlController: controller,
            onProviderChanged: (value) => selectedProvider = value,
            onUrlChanged: () {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('test_playlist_provider_field_false')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spotify').last);
    await tester.pumpAndSettle();

    expect(selectedProvider, 'spotify');
  });
}
