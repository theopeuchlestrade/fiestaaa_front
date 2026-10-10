import 'package:fiestaaa_front/src/core/presentation/widgets/fiestaaa_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Entrance completes once and does not restart on content refresh',
    (tester) async {
      Widget view(String text) => MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FiestaaaEntrance(child: Text(text)),
        ),
      );
      await tester.pumpWidget(view('Loaded content'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      await tester.pumpWidget(view('Updated content'));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      expect(find.text('Updated content'), findsOneWidget);
    },
  );
  for (final accessibleNavigation in [false, true]) {
    testWidgets(
      'Accessibility preferences render immediately ($accessibleNavigation)',
      (tester) async {
        Duration? duration;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              disableAnimations: !accessibleNavigation,
              accessibleNavigation: accessibleNavigation,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  duration = fiestaaaMotionDuration(context);
                  return const FiestaaaEntrance(child: Text('Ready now'));
                },
              ),
            ),
          ),
        );
        expect(find.text('Ready now'), findsOneWidget);
        expect(find.byType(Opacity), findsNothing);
        expect(find.byType(Transform), findsNothing);
        expect(duration, Duration.zero);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }
}
