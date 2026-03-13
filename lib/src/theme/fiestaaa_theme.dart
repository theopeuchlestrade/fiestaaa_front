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
  static const Color lightSurfaceLow = Color(0xFFFBFBFF);
  static const Color lightSurfaceHigh = Color(0xFFEFF2FF);
  static const Color lightSurfaceHighest = Color(0xFFE5EBFB);
  static const Color darkSurfaceLow = Color(0xFF101726);
  static const Color darkSurfaceHigh = Color(0xFF182236);
  static const Color darkSurfaceHighest = Color(0xFF202A40);
  static const Color lightOutline = Color(0xFFD3DAEE);
  static const Color lightOutlineVariant = Color(0xFFE3E8F7);
  static const Color darkOutline = Color(0xFF45506A);
  static const Color darkOutlineVariant = Color(0xFF303A50);
  static const Color success = Color(0xFF15803D);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color successContainerDark = Color(0xFF153321);
  static const Color warning = Color(0xFF526277);
  static const Color warningDark = Color(0xFFD7DEE9);
  static const Color warningContainer = Color(0xFFE2E8F0);
  static const Color warningContainerDark = Color(0xFF2B3444);
  static const Color info = Color(0xFF0F766E);
  static const Color infoDark = Color(0xFF9BE8FA);
  static const Color infoContainer = Color(0xFFDCFDF7);
  static const Color infoContainerDark = Color(0xFF133742);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color dangerContainer = Color(0xFFFEE2E2);
  static const Color dangerContainerDark = Color(0xFF4B1E22);

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

enum FiestaaaStatusTone { primary, success, warning, neutral, info, danger }

class FiestaaaStatusStyle {
  const FiestaaaStatusStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

extension FiestaaaColorSchemeX on ColorScheme {
  bool get fiestaaaIsDark => brightness == Brightness.dark;

  Color get fiestaaaMutedForeground => onSurfaceVariant;

  Color get fiestaaaSubtleForeground =>
      onSurface.withValues(alpha: fiestaaaIsDark ? 0.62 : 0.68);

  Color get fiestaaaSurfaceMuted => fiestaaaIsDark
      ? surfaceContainerHigh.withValues(alpha: 0.92)
      : surfaceContainerLow;

  Color get fiestaaaSurfaceSoft => fiestaaaIsDark
      ? surfaceContainerHighest.withValues(alpha: 0.82)
      : surfaceContainerHighest;

  Color get fiestaaaAvatarSurface =>
      fiestaaaIsDark ? surfaceContainerHighest : surfaceContainerHigh;

  Color get fiestaaaSuccess =>
      fiestaaaIsDark ? FiestaaaPalette.successDark : FiestaaaPalette.success;

  Color get fiestaaaSuccessContainer => fiestaaaIsDark
      ? FiestaaaPalette.successContainerDark
      : FiestaaaPalette.successContainer;

  Color get fiestaaaWarning =>
      fiestaaaIsDark ? FiestaaaPalette.warningDark : FiestaaaPalette.warning;

  Color get fiestaaaWarningContainer => fiestaaaIsDark
      ? FiestaaaPalette.warningContainerDark
      : FiestaaaPalette.warningContainer;

  Color get fiestaaaInfo =>
      fiestaaaIsDark ? FiestaaaPalette.infoDark : FiestaaaPalette.info;

  Color get fiestaaaInfoContainer => fiestaaaIsDark
      ? FiestaaaPalette.infoContainerDark
      : FiestaaaPalette.infoContainer;

  Color get fiestaaaNeutral =>
      fiestaaaIsDark ? const Color(0xFFD4C4FF) : onSurfaceVariant;

  Color get fiestaaaNeutralContainer =>
      fiestaaaIsDark ? surfaceContainerHigh : surfaceContainerHighest;

  Color get fiestaaaDanger =>
      fiestaaaIsDark ? FiestaaaPalette.dangerDark : FiestaaaPalette.danger;

  Color get fiestaaaDangerContainer => fiestaaaIsDark
      ? FiestaaaPalette.dangerContainerDark
      : FiestaaaPalette.dangerContainer;

  FiestaaaStatusStyle fiestaaaStatus(FiestaaaStatusTone tone) {
    switch (tone) {
      case FiestaaaStatusTone.primary:
        final foreground = primary;
        return FiestaaaStatusStyle(
          foreground: foreground,
          background: foreground.withValues(alpha: fiestaaaIsDark ? 0.2 : 0.12),
          border: foreground.withValues(alpha: fiestaaaIsDark ? 0.36 : 0.24),
        );
      case FiestaaaStatusTone.success:
        final foreground = fiestaaaSuccess;
        return FiestaaaStatusStyle(
          foreground: foreground,
          background: fiestaaaSuccessContainer,
          border: foreground.withValues(alpha: fiestaaaIsDark ? 0.44 : 0.18),
        );
      case FiestaaaStatusTone.warning:
        final foreground = fiestaaaWarning;
        return FiestaaaStatusStyle(
          foreground: foreground,
          background: fiestaaaWarningContainer,
          border: foreground.withValues(alpha: fiestaaaIsDark ? 0.42 : 0.18),
        );
      case FiestaaaStatusTone.neutral:
        final foreground = fiestaaaNeutral;
        return FiestaaaStatusStyle(
          foreground: foreground,
          background: fiestaaaNeutralContainer,
          border: foreground.withValues(alpha: fiestaaaIsDark ? 0.36 : 0.2),
        );
      case FiestaaaStatusTone.info:
        final foreground = fiestaaaInfo;
        return FiestaaaStatusStyle(
          foreground: foreground,
          background: fiestaaaInfoContainer,
          border: foreground.withValues(alpha: fiestaaaIsDark ? 0.42 : 0.18),
        );
      case FiestaaaStatusTone.danger:
        final foreground = fiestaaaDanger;
        return FiestaaaStatusStyle(
          foreground: foreground,
          background: fiestaaaDangerContainer,
          border: foreground.withValues(alpha: fiestaaaIsDark ? 0.42 : 0.22),
        );
    }
  }
}

extension FiestaaaThemeDataX on ThemeData {
  Color get fiestaaaMutedText => colorScheme.fiestaaaMutedForeground;
  Color get fiestaaaSubtleText => colorScheme.fiestaaaSubtleForeground;
  Color get fiestaaaSoftSurface => colorScheme.fiestaaaSurfaceSoft;
  Color get fiestaaaMutedSurface => colorScheme.fiestaaaSurfaceMuted;
  Color get fiestaaaAvatarSurface => colorScheme.fiestaaaAvatarSurface;
  Color get fiestaaaSoftBorder => colorScheme.outlineVariant;
  Color get fiestaaaTicketSurface => Colors.white;
  Color get fiestaaaTicketText => const Color(0xFF1F2937);
  Color get fiestaaaTicketMutedText => const Color(0xFF6B7280);
  Color get fiestaaaTicketSubtleText => const Color(0xFF9CA3AF);
  Color get fiestaaaTicketDivider => const Color(0xFFD1D5DB);
  Color get fiestaaaTicketEdge => const Color(0xFFEEEEEE);
  Color get fiestaaaScrim => colorScheme.scrim.withValues(
    alpha: brightness == Brightness.dark ? 0.64 : 0.5,
  );
}

FiestaaaStatusStyle fiestaaaInvitationStatusStyle(
  ColorScheme scheme,
  String status,
) {
  switch (status) {
    case 'Accepted':
      return scheme.fiestaaaStatus(FiestaaaStatusTone.success);
    case 'Waiting':
    case 'Pending':
      return scheme.fiestaaaStatus(FiestaaaStatusTone.warning);
    case 'Declined':
    case 'Expired':
      return scheme.fiestaaaStatus(FiestaaaStatusTone.neutral);
    default:
      return scheme.fiestaaaStatus(FiestaaaStatusTone.neutral);
  }
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
  final surfaceLow = isDark
      ? FiestaaaPalette.darkSurfaceLow
      : FiestaaaPalette.lightSurfaceLow;
  final surfaceHigh = isDark
      ? FiestaaaPalette.darkSurfaceHigh
      : FiestaaaPalette.lightSurfaceHigh;
  final surfaceHighest = isDark
      ? FiestaaaPalette.darkSurfaceHighest
      : FiestaaaPalette.lightSurfaceHighest;
  final outlineColor = isDark
      ? FiestaaaPalette.darkOutline
      : FiestaaaPalette.lightOutline;
  final outlineVariant = isDark
      ? FiestaaaPalette.darkOutlineVariant
      : FiestaaaPalette.lightOutlineVariant;
  final mutedText = textColor.withValues(alpha: isDark ? 0.72 : 0.7);
  final bodyText = textColor.withValues(alpha: isDark ? 0.8 : 0.84);
  final inputLabelColor = mutedText;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: FiestaaaPalette.primary,
        brightness: brightness,
      ).copyWith(
        primary: FiestaaaPalette.primary,
        secondary: FiestaaaPalette.secondary,
        tertiary: FiestaaaPalette.accent,
        surface: surfaceRaised,
        surfaceContainerLowest: surfaceColor,
        surfaceContainerLow: surfaceLow,
        surfaceContainer: surfaceRaised,
        surfaceContainerHigh: surfaceHigh,
        surfaceContainerHighest: surfaceHighest,
        onSurface: textColor,
        onSurfaceVariant: mutedText,
        onPrimary: Colors.white,
        onSecondary: isDark
            ? FiestaaaPalette.darkSurface
            : FiestaaaPalette.lightText,
        outline: outlineColor,
        outlineVariant: outlineVariant,
        primaryContainer: isDark
            ? const Color(0xFF241F52)
            : const Color(0xFFE8E3FF),
        secondaryContainer: isDark
            ? const Color(0xFF123446)
            : const Color(0xFFDDF9FF),
        tertiaryContainer: isDark
            ? const Color(0xFF2B2144)
            : const Color(0xFFF0E9FF),
        error: isDark ? FiestaaaPalette.dangerDark : FiestaaaPalette.danger,
        errorContainer: isDark
            ? FiestaaaPalette.dangerContainerDark
            : FiestaaaPalette.dangerContainer,
        scrim: Colors.black,
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
        borderSide: BorderSide(color: colorScheme.outline),
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
        borderSide: BorderSide(color: colorScheme.outline),
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
    dividerColor: colorScheme.outlineVariant,
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
