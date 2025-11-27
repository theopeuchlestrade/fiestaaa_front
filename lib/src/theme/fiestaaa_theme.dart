import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FiestaaaPalette {
  static const Color primary = Color(0xFF6B4DF5);
  static const Color secondary = Color(0xFF4FD3F3);
  static const Color accent = Color(0xFF8C7BFF);
  static const Color text = Color(0xFF0F172A);
  static const Color surface = Color(0xFFF6F7FF);

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF6F7FF), Color(0xFFE8ECFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF7D5BFF), Color(0xFF4F7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF5D5FEF), Color(0xFF4FD3F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildFiestaaaTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: FiestaaaPalette.primary,
    brightness: Brightness.light,
  );

  final baseTextTheme = GoogleFonts.manropeTextTheme();
  final textTheme = baseTextTheme.copyWith(
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: FiestaaaPalette.text,
      letterSpacing: -0.4,
    ),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: FiestaaaPalette.text,
      letterSpacing: -0.2,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: FiestaaaPalette.text,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(
      color: FiestaaaPalette.text.withOpacity(0.82),
      height: 1.4,
    ),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(
      color: FiestaaaPalette.text.withOpacity(0.76),
      height: 1.4,
    ),
  );

  return ThemeData(
    colorScheme: colorScheme.copyWith(
      primary: FiestaaaPalette.primary,
      secondary: FiestaaaPalette.secondary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: FiestaaaPalette.surface,
    useMaterial3: true,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white.withOpacity(0.88),
      surfaceTintColor: Colors.white,
      foregroundColor: FiestaaaPalette.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FiestaaaPalette.primary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            const BorderSide(color: FiestaaaPalette.primary, width: 1.6),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
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
      backgroundColor: Colors.white.withOpacity(0.94),
      selectedItemColor: FiestaaaPalette.primary,
      unselectedItemColor: Colors.grey.shade500,
      elevation: 12,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    dividerColor: Colors.grey.shade200,
  );
}

class FiestaaaBackground extends StatelessWidget {
  const FiestaaaBackground({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final paddedChild =
        padding != null ? Padding(padding: padding!, child: child) : child;
    return Container(
      decoration:
          const BoxDecoration(gradient: FiestaaaPalette.backgroundGradient),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -60,
            child: _AccentBlob(
              size: 220,
              color: FiestaaaPalette.primary.withOpacity(0.16),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: _AccentBlob(
              size: 200,
              color: FiestaaaPalette.secondary.withOpacity(0.22),
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
          colors: [color, color.withOpacity(0.01)],
        ),
      ),
    );
  }
}
