import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    test(
      'semantic color pairs meet normal text contrast (${dark ? 'dark' : 'light'})',
      () {
        final c = (dark ? buildFiestaaaDarkTheme() : buildFiestaaaTheme())
            .colorScheme;
        final borderRatio =
            (c.outline.computeLuminance() + .05) /
            (c.surface.computeLuminance() + .05);
        expect(
          borderRatio >= 1 ? borderRatio : 1 / borderRatio,
          greaterThanOrEqualTo(3),
          reason: 'Input boundary contrast',
        );
        final pairs = <String, (Color, Color)>{
          'primary': (c.onPrimary, c.primary),
          'secondary': (c.onSecondary, c.secondary),
          'tertiary': (c.onTertiary, c.tertiary),
          'error': (c.onError, c.error),
          'primary container': (c.onPrimaryContainer, c.primaryContainer),
          'secondary container': (c.onSecondaryContainer, c.secondaryContainer),
          'tertiary container': (c.onTertiaryContainer, c.tertiaryContainer),
          'error container': (c.onErrorContainer, c.errorContainer),
        };
        for (final entry in pairs.entries) {
          final a = entry.value.$1.computeLuminance();
          final b = entry.value.$2.computeLuminance();
          final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: $ratio',
          );
        }
      },
    );
  }
}
