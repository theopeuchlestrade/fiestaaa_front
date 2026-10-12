import 'package:flutter/material.dart';

/// Official Google gradient G from the approved 2026 sign-in asset bundle.
/// Display the central 20/40 logo region without recoloring or distorting it.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: OverflowBox(
          minWidth: size * 2,
          maxWidth: size * 2,
          minHeight: size * 2,
          maxHeight: size * 2,
          child: Image.asset('assets/identity/google-signin-light-4x.png'),
        ),
      ),
    ),
  );
}
