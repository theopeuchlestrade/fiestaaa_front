import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FiestaaaPalette {
  static const Color primary = Color(0xFF6B4DF5);
  static const Color secondary = Color(0xFF4FD3F3);
  static const Color accent = Color(0xFF8C7BFF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color darkText = Color(0xFFE2E8F0);
  static const Color lightSurface = Color(0xFFF6F7FF);
  static const Color darkSurface = Color(0xFF0B0F1A);
  static const Color darkSurfaceRaised = Color(0xFF141B2D);

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF6F7FF), Color(0xFFE8ECFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0B0F1A), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    colors: [Color(0xFF7D5BFF), Color(0xFF4F7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF2C2A6F), Color(0xFF21437E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightButtonGradient = LinearGradient(
    colors: [Color(0xFF5D5FEF), Color(0xFF4FD3F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkButtonGradient = LinearGradient(
    colors: [Color(0xFF5D5FEF), Color(0xFF2FA7C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color textFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkText : lightText;

  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color surfaceRaisedFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceRaised : Colors.white;

  static LinearGradient backgroundGradientFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkBackgroundGradient
      : lightBackgroundGradient;

  static LinearGradient cardGradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkCardGradient : lightCardGradient;

  static LinearGradient buttonGradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkButtonGradient : lightButtonGradient;
}

ThemeData buildFiestaaaTheme() {
  return _buildFiestaaaTheme(Brightness.light);
}

ThemeData buildFiestaaaDarkTheme() {
  return _buildFiestaaaTheme(Brightness.dark);
}

ThemeData _buildFiestaaaTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textColor = FiestaaaPalette.textFor(brightness);
  final surfaceColor = FiestaaaPalette.surfaceFor(brightness);
  final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);
  final outlineColor = isDark ? Colors.white24 : Colors.grey.shade300;
  final dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;
  final mutedText = textColor.withValues(alpha: isDark ? 0.7 : 0.76);
  final bodyText = textColor.withValues(alpha: isDark ? 0.78 : 0.82);
  final inputLabelColor = isDark ? mutedText : Colors.grey.shade700;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: FiestaaaPalette.primary,
        brightness: brightness,
      ).copyWith(
        primary: FiestaaaPalette.primary,
        secondary: FiestaaaPalette.secondary,
        surface: surfaceRaised,
        onSurface: textColor,
        onPrimary: Colors.white,
        onSecondary: isDark
            ? FiestaaaPalette.darkSurface
            : FiestaaaPalette.lightText,
      );

  final baseTextTheme = GoogleFonts.manropeTextTheme().apply(
    bodyColor: textColor,
    displayColor: textColor,
  );
  final textTheme = baseTextTheme.copyWith(
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: -0.4,
    ),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: -0.2,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: bodyText, height: 1.4),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(
      color: mutedText,
      height: 1.4,
    ),
  );

  return ThemeData(
    colorScheme: colorScheme.copyWith(
      primary: FiestaaaPalette.primary,
      secondary: FiestaaaPalette.secondary,
      surface: surfaceRaised,
    ),
    scaffoldBackgroundColor: surfaceColor,
    useMaterial3: true,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceRaised.withValues(alpha: isDark ? 0.92 : 0.88),
      surfaceTintColor: surfaceRaised,
      foregroundColor: textColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surfaceRaised,
      surfaceTintColor: surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FiestaaaPalette.primary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outlineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: FiestaaaPalette.primary,
          width: 1.6,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outlineColor),
      ),
      labelStyle: TextStyle(color: inputLabelColor),
      prefixIconColor: FiestaaaPalette.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FiestaaaPalette.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FiestaaaPalette.primary,
        side: const BorderSide(color: FiestaaaPalette.primary),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceRaised.withValues(alpha: isDark ? 0.92 : 0.94),
      selectedItemColor: FiestaaaPalette.primary,
      unselectedItemColor: textColor.withValues(alpha: 0.58),
      elevation: 12,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceRaised,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerColor: dividerColor,
  );
}

const EdgeInsets fiestaaaPagePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 20,
);

class FiestaaaPageLayout extends StatelessWidget {
  const FiestaaaPageLayout({
    super.key,
    required this.child,
    this.padding = fiestaaaPagePadding,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return FiestaaaBackground(
      padding: padding,
      child: SafeArea(child: child),
    );
  }
}

class FiestaaaPageHeader extends StatelessWidget {
  const FiestaaaPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleSpacing = 6,
    this.bottomSpacing = 16,
  });

  final String title;
  final String? subtitle;
  final double subtitleSpacing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          SizedBox(height: subtitleSpacing),
          Text(subtitle!, style: textTheme.bodyMedium),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

class FiestaaaBackground extends StatelessWidget {
  const FiestaaaBackground({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paddedChild = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    return Container(
      decoration: BoxDecoration(
        gradient: FiestaaaPalette.backgroundGradientFor(brightness),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -60,
            child: _AccentBlob(
              size: 220,
              color: FiestaaaPalette.primary.withValues(
                alpha: brightness == Brightness.dark ? 0.22 : 0.16,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: _AccentBlob(
              size: 200,
              color: FiestaaaPalette.secondary.withValues(
                alpha: brightness == Brightness.dark ? 0.26 : 0.22,
              ),
            ),
          ),
          paddedChild,
        ],
      ),
    );
  }
}

class _AccentBlob extends StatelessWidget {
  const _AccentBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.01)],
        ),
      ),
    );
  }
}
