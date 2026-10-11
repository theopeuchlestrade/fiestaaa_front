import 'package:fiestaaa_front/src/core/presentation/widgets/quasi_fullscreen_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('modal heading wraps at enlarged text without hiding close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title = 'Ajouter une contribution à ce besoin';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: QuasiFullscreenModalScaffold(title: title, child: Text('Form')),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text(title)).maxLines, isNull);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
