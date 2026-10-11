import 'package:flutter/material.dart';

/// Short, one-time entrance. Motion never delays interaction or replaces data.
class FiestaaaEntrance extends StatelessWidget {
  const FiestaaaEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations == true ||
        media?.accessibleNavigation == true) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - progress)),
          child: child,
        ),
      ),
    );
  }
}

Duration fiestaaaMotionDuration(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  return media?.disableAnimations == true || media?.accessibleNavigation == true
      ? Duration.zero
      : const Duration(milliseconds: 180);
}
