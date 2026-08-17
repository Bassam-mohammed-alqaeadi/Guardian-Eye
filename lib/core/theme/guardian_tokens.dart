import 'package:flutter/material.dart';

/// Guardian Eye Pro visual token system.
///
/// This is the single source of visual truth for the platform. Every
/// screen, primitive, and theme configuration reads from these tokens —
/// never from ad-hoc `Colors.xxx` or numeric literals.
///
/// Design intent: Trust · Safety · Calm · Intelligence · Family ·
/// Premium · Modernity · Clarity. The brand language is a deep
/// Guardian navy anchored by an intelligence teal, with honest, calm
/// status colors that never dramatize.
///
/// Tokens are intentionally additive: legacy [AppColors] values remain
/// untouched for backward compatibility with committed code.
class GuardianTokens {
  GuardianTokens._();

  // ─── Brand ────────────────────────────────────────────────────────────────

  /// Deep Guardian navy — the trust surface. Used for headers, app bars,
  /// the bottom navigation shell, and primary brand marks.
  static const Color guardianNavy = Color(0xFF0F2A5B);
  static const Color guardianNavyDeep = Color(0xFF0A1F44);
  static const Color guardianNavySoft = Color(0xFF163872);

  /// Intelligence teal — the "smart protection" accent. Gradients,
  /// progress arcs, active states, AI surfaces.
  static const Color guardianTeal = Color(0xFF00B8A9);
  static const Color guardianTealLight = Color(0xFF2DD4BF);
  static const Color guardianTealDeep = Color(0xFF00897B);
  static const Color guardianTealSoft = Color(0xFFCCF2EE);

  /// The brand gradient: navy → teal intelligence sweep.
  static const LinearGradient guardianGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [guardianNavy, guardianNavySoft, guardianTealDeep],
    stops: [0.0, 0.62, 1.0],
  );

  /// Surface gradient for hero cards and the safety score ring.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [guardianNavyDeep, guardianNavySoft],
  );

  // ─── Surfaces ─────────────────────────────────────────────────────────────

  static const Color surfaceLight = Color(0xFFF7F9FC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0B1220);
  static const Color cardDark = Color(0xFF141C2E);
  static const Color dividerLight = Color(0xFFE3E9F2);
  static const Color dividerDark = Color(0xFF24304A);

  // ─── Semantic status ──────────────────────────────────────────────────────
  // Honest, calm status colors — no dramatization, no red-on-red alarm
  // unless the event genuinely is SOS-grade.

  static const Color statusSafe = Color(0xFF0FA87D);
  static const Color statusSafeSoft = Color(0xFFDCF5EC);
  static const Color statusWatch = Color(0xFFE8A33D);
  static const Color statusWatchSoft = Color(0xFFFDF0DB);
  static const Color statusAlert = Color(0xFFE2574C);
  static const Color statusAlertSoft = Color(0xFFFDE3E1);
  static const Color statusOffline = Color(0xFF6B7A99);
  static const Color statusOfflineSoft = Color(0xFFE8EDF6);
  static const Color statusSOS = Color(0xFFC62828);
  static const Color statusSOSDeep = Color(0xFF8E1B1B);
  static const Color statusPro = Color(0xFF7C5CFC);
  static const Color statusProSoft = Color(0xFFEDE8FF);

  // ─── Typography scale (Cairo, already the app font) ───────────────────────

  static const String fontFamily = 'Cairo';

  static const double display = 30;
  static const double headline = 22;
  static const double title = 18;
  static const double body = 15;
  static const double caption = 13;
  static const double overline = 11;

  // ─── Geometry ─────────────────────────────────────────────────────────────

  static const double radiusCard = 16.0;
  static const double radiusCardLarge = 20.0;
  static const double radiusPill = 999.0;
  static const double radiusChip = 12.0;
  static const double radiusButton = 14.0;
  static const double radiusBottomSheet = 24.0;

  static const double gutter = 16.0;
  static const double gutterLg = 20.0;
  static const double gutterSm = 8.0;

  static const double bottomNavHeight = 72.0;
  static const double appBarMinHeight = 64.0;

  // ─── Elevation / surfaces ─────────────────────────────────────────────────

  static const double elevationCard = 0.0; // flat cards, hairline separation
  static const double elevationFloating = 2.0;
  static const double elevationNav = 8.0;
}

/// Screen-size classes used by the responsive layout utilities.
enum GuardianLayoutClass { compact, medium, expanded }

/// Simple width-driven layout classification for phones and tablets.
class GuardianLayout {
  GuardianLayout._();

  static GuardianLayoutClass classify(double width) {
    if (width >= 900) return GuardianLayoutClass.expanded;
    if (width >= 600) return GuardianLayoutClass.medium;
    return GuardianLayoutClass.compact;
  }

  /// Max content width so layouts stay readable on tablets.
  static const double maxWidthCompact = 480.0;
}
