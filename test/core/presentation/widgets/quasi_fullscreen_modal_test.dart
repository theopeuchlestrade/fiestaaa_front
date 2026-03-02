import 'package:fiestaaa_front/src/core/presentation/widgets/quasi_fullscreen_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showQuasiFullscreenModal affiche le contenu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showQuasiFullscreenModal<void>(
                  context: context,
                  builder: (_) => const QuasiFullscreenModalScaffold(
                    title: 'Section',
                    child: Text('Contenu modal'),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Contenu modal'), findsOneWidget);
  });

  testWidgets('le bouton fermer ferme la modal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showQuasiFullscreenModal<void>(
                  context: context,
                  builder: (_) => const QuasiFullscreenModalScaffold(
                    title: 'Section',
                    child: Text('Contenu modal'),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Contenu modal'), findsNothing);
  });
}
