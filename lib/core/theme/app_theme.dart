import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'guardian_tokens.dart';

/// Canonical Guardian Eye Pro design system.
///
/// ONE theme for the whole platform: every screen, primitive, and
/// global state reads from this `AppTheme`. No inline `ThemeData`,
/// no ad-hoc colors, no duplicated card or button styling anywhere
/// in `lib/presentation`.
///
/// The light theme is the production default (trust/safety product
/// reads clearest on a calm light surface); the dark theme is the
/// same system mirrored, so both stay visually one product.
class AppTheme {
  AppTheme._();

  // ── Entry points ─────────────────────────────────────────────────────────

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  // ── System construction ──────────────────────────────────────────────────

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    // Brand navy is the primary; intelligence teal is the secondary.
    // Surface container tokens are the modern M3 surface tiers
    // (surfaceContainerHighest replaces the deprecated surfaceVariant).
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: dark ? AppColors.primaryDark : GuardianTokens.guardianNavy,
      onPrimary: Colors.white,
      secondary: dark ? AppColors.secondaryDark : GuardianTokens.guardianTeal,
      onSecondary: Colors.white,
      tertiary: GuardianTokens.guardianTeal,
      surface: dark ? GuardianTokens.surfaceDark : GuardianTokens.surfaceLight,
      onSurface: dark
          ? GuardianTokens.cardDark
          : const Color(0xFF12203A),
      surfaceContainer: dark
          ? const Color(0xFF141C2E)
          : const Color(0xFFFDFEFF),
      surfaceContainerHigh: dark
          ? const Color(0xFF1B2538)
          : const Color(0xFFF4F7FB),
      surfaceContainerHighest: dark
          ? const Color(0xFF232E46)
          : const Color(0xFFEDF2F9),
      surfaceDim: dark
          ? const Color(0xFF0B1220)
          : const Color(0xFFEEF2F8),
      onSurfaceVariant: dark
          ? const Color(0xFFB9C4D8)
          : const Color(0xFF4A5A78),
      error: GuardianTokens.statusAlert,
      onError: Colors.white,
      outline: dark ? GuardianTokens.dividerDark : GuardianTokens.dividerLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: GuardianTokens.fontFamily,
      textTheme: _textTheme(colorScheme, dark),
      appBarTheme: _appBarTheme(colorScheme, dark),
      cardTheme: _cardTheme(colorScheme),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _filledButtonTheme(colorScheme)),
      filledButtonTheme:
          FilledButtonThemeData(style: _filledButtonTheme(colorScheme)),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: _outlinedButtonTheme(colorScheme)),
      textButtonTheme:
          TextButtonThemeData(style: _textButtonTheme(colorScheme)),
      chipTheme: _chipTheme(colorScheme, dark),
      switchTheme: _switchTheme(colorScheme, dark),
      listTileTheme: _listTileTheme(colorScheme),
      inputDecorationTheme: _inputTheme(colorScheme),
      snackBarTheme: _snackBarTheme(colorScheme),
      bottomSheetTheme: _bottomSheetTheme(colorScheme),
      progressIndicatorTheme: _progressTheme(colorScheme),
      dividerTheme: _dividerTheme(dark),
      dialogTheme: _dialogTheme(colorScheme),
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.secondary,
        textColor: Colors.white,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Typography ───────────────────────────────────────────────────────────

  static TextTheme _textTheme(ColorScheme cs, bool dark) {
    final onSurface = cs.onSurface;
    final onVariant = cs.onSurfaceVariant;
    final base = const TextTheme().apply(fontFamily: GuardianTokens.fontFamily);
    return base.copyWith(
      displayLarge: TextStyle(
        fontSize: GuardianTokens.display,
        fontWeight: FontWeight.w800,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: GuardianTokens.headline,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: GuardianTokens.title,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: GuardianTokens.body,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onVariant,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: onVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onVariant,
      ),
      labelSmall: TextStyle(
        fontSize: GuardianTokens.overline,
        fontWeight: FontWeight.w700,
        color: onVariant,
        letterSpacing: 0.8,
      ),
    );
  }

  // ── Component themes ─────────────────────────────────────────────────────

  static AppBarTheme _appBarTheme(ColorScheme cs, bool dark) {
    return AppBarTheme(
      backgroundColor: dark ? cs.primary : GuardianTokens.guardianNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 23),
    );
  }

  static CardThemeData _cardTheme(ColorScheme cs) {
    return CardThemeData(
      color: cs.surface == cs.surface
          ? (cs.brightness == Brightness.dark
              ? GuardianTokens.cardDark
              : GuardianTokens.cardLight)
          : cs.surface,
      shadowColor: cs.primary.withValues(alpha: 0.06),
      elevation: GuardianTokens.elevationCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusCard),
        side: BorderSide(
          color: cs.outline,
          width: 0.5,
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    );
  }

  static ButtonStyle _filledButtonTheme(ColorScheme cs) {
    return ElevatedButton.styleFrom(
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(120, 48),
      maximumSize: const Size(600, 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
      ),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: const TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ButtonStyle _outlinedButtonTheme(ColorScheme cs) {
    return OutlinedButton.styleFrom(
      foregroundColor: cs.primary,
      side: BorderSide(color: cs.outline, width: 1.2),
      minimumSize: const Size(88, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      textStyle: const TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ButtonStyle _textButtonTheme(ColorScheme cs) {
    return TextButton.styleFrom(
      foregroundColor: cs.primary,
      textStyle: const TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ChipThemeData _chipTheme(ColorScheme cs, bool dark) {
    return ChipThemeData(
      backgroundColor: dark ? cs.surfaceContainerHigh : GuardianTokens.surfaceLight,
      side: BorderSide(color: cs.outline, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusChip),
      ),
      labelStyle: const TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    );
  }

  static SwitchThemeData _switchTheme(ColorScheme cs, bool dark) {
    final trackOff = dark
        ? cs.surfaceContainerHigh
        : GuardianTokens.surfaceLight;
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? cs.secondary : cs.outline),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? cs.secondary
              : trackOff),
    );
  }

  static ListTileThemeData _listTileTheme(ColorScheme cs) {
    return ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusCard),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      titleTextStyle: TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 13,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  static InputDecorationTheme _inputTheme(ColorScheme cs) {
    return InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
        borderSide: BorderSide(color: cs.outline, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
        borderSide: BorderSide(color: cs.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
        borderSide: BorderSide(color: cs.error, width: 1.0),
      ),
      labelStyle: TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 14,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(ColorScheme cs) {
    return SnackBarThemeData(
      backgroundColor: cs.primary,
      contentTextStyle: const TextStyle(
        fontFamily: GuardianTokens.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusButton),
      ),
      behavior: SnackBarBehavior.floating,
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme cs) {
    return BottomSheetThemeData(
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GuardianTokens.radiusBottomSheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  static ProgressIndicatorThemeData _progressTheme(ColorScheme cs) {
    return ProgressIndicatorThemeData(
      color: cs.secondary,
      linearTrackColor: cs.surfaceContainerHighest,
    );
  }

  static DividerThemeData _dividerTheme(bool dark) {
    return DividerThemeData(
      color: dark ? GuardianTokens.dividerDark : GuardianTokens.dividerLight,
      thickness: 0.5,
    );
  }

  static DialogThemeData _dialogTheme(ColorScheme cs) {
    return DialogThemeData(
      backgroundColor:
          cs.brightness == Brightness.dark
              ? GuardianTokens.cardDark
              : GuardianTokens.cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardianTokens.radiusCardLarge),
        side: BorderSide(color: cs.outline, width: 0.5),
      ),
    );
  }
}
