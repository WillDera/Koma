import 'package:flutter/material.dart';

/// Koma design tokens — colors.
///
/// Three modes (light, dark, sepia) with one sophisticated indigo anchor.
/// All colors are intentionally desaturated to support long reading sessions
/// without fatigue. No pure white, no pure black.
class AppColors {
  AppColors._();

  // ─── Light (warm paper) ────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF5F2EC);
  static const Color lightBgElevated = Color(0xFFFBFAF6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEFEBE3);
  static const Color lightBorder = Color(0xFFE5E0D6);
  static const Color lightBorderStrong = Color(0xFFC9C2B2);
  static const Color lightTextPrimary = Color(0xFF1A1815);
  static const Color lightTextSecondary = Color(0xFF6E6A60);
  static const Color lightTextTertiary = Color(0xFF9A9486);
  static const Color lightAccent = Color(0xFF4A4FD8);
  static const Color lightAccentMuted = Color(0xFFEEF0FD);
  static const Color lightAccentText = Color(0xFFFFFFFF);
  static const Color lightOnAccent = Color(0xFFFFFFFF);

  // ─── Dark (cool charcoal) ──────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0E0E10);
  static const Color darkBgElevated = Color(0xFF16171A);
  static const Color darkSurface = Color(0xFF1B1C1F);
  static const Color darkSurfaceMuted = Color(0xFF22232A);
  static const Color darkBorder = Color(0xFF2A2B30);
  static const Color darkBorderStrong = Color(0xFF3A3B42);
  static const Color darkTextPrimary = Color(0xFFF2EFEA);
  static const Color darkTextSecondary = Color(0xFFA6A29B);
  static const Color darkTextTertiary = Color(0xFF6E6A66);
  static const Color darkAccent = Color(0xFF7C82F0);
  static const Color darkAccentMuted = Color(0xFF1E1F35);
  static const Color darkAccentText = Color(0xFF0E0E10);
  static const Color darkOnAccent = Color(0xFF0E0E10);

  // ─── Sepia (paper) ─────────────────────────────────────────────────────
  static const Color sepiaBg = Color(0xFFF2E8D5);
  static const Color sepiaBgElevated = Color(0xFFF8EFDD);
  static const Color sepiaSurface = Color(0xFFFCF5E4);
  static const Color sepiaSurfaceMuted = Color(0xFFE9DCC2);
  static const Color sepiaBorder = Color(0xFFD8C8A8);
  static const Color sepiaBorderStrong = Color(0xFFB89B6A);
  static const Color sepiaTextPrimary = Color(0xFF3F2E1A);
  static const Color sepiaTextSecondary = Color(0xFF7A6248);
  static const Color sepiaTextTertiary = Color(0xFFA48B6A);
  static const Color sepiaAccent = Color(0xFFA86A37);
  static const Color sepiaAccentMuted = Color(0xFFF0DCC4);
  static const Color sepiaAccentText = Color(0xFFFCF5E4);
  static const Color sepiaOnAccent = Color(0xFFFCF5E4);

  // ─── Semantic (same across modes; tuned for contrast) ──────────────────
  static const Color success = Color(0xFF4F8A55);
  static const Color successMuted = Color(0xFFE6F0E7);
  static const Color danger = Color(0xFFC44C4C);
  static const Color dangerMuted = Color(0xFFFAE3E3);
  static const Color warning = Color(0xFFC18A2A);
  static const Color warningMuted = Color(0xFFF7ECDA);

  // ─── Highlight palette (used in text selection & snippet colors) ──────
  // Each is a (light, dark, sepia) triple for the four highlight hues.
  static const Color highlightYellowLight = Color(0xFFFFE8A8);
  static const Color highlightBlueLight = Color(0xFFC8D8FF);
  static const Color highlightPinkLight = Color(0xFFFFD4DC);
  static const Color highlightGreenLight = Color(0xFFC8E6C9);

  static const Color highlightYellowDark = Color(0xFF5C4A1E);
  static const Color highlightBlueDark = Color(0xFF1F2A55);
  static const Color highlightPinkDark = Color(0xFF552033);
  static const Color highlightGreenDark = Color(0xFF1F3D24);

  static const Color highlightYellowSepia = Color(0xFFE8D08A);
  static const Color highlightBlueSepia = Color(0xFFB8C4D8);
  static const Color highlightPinkSepia = Color(0xFFE8B8B8);
  static const Color highlightGreenSepia = Color(0xFFB8C8A8);

  // ─── Glass surface tints (used by nav pill & sheets with blur) ────────
  static const Color glassLight = Color(0xCCFBFAF6);
  static const Color glassDark = Color(0xCC16171A);
  static const Color glassSepia = Color(0xCCF8EFDD);

  // ─── Accent presets (Settings → Accent color) ─────────────────────────
  static const Color accentIndigo = Color(0xFF4A4FD8);
  static const Color accentIndigoDark = Color(0xFF7C82F0);
  static const Color accentAmber = Color(0xFFB07D52);
  static const Color accentAmberDark = Color(0xFFD4A277);
  static const Color accentForest = Color(0xFF4F7A55);
  static const Color accentForestDark = Color(0xFF7AAE82);

  /// Returns the appropriate highlight color for the given triple key
  /// (one of 'yellow' | 'blue' | 'pink' | 'green') for the given brightness.
  static Color highlight(String key, Brightness brightness, {bool isSepia = false}) {
    if (isSepia) {
      switch (key) {
        case 'blue':
          return highlightBlueSepia;
        case 'pink':
          return highlightPinkSepia;
        case 'green':
          return highlightGreenSepia;
        case 'yellow':
        default:
          return highlightYellowSepia;
      }
    }
    final isDark = brightness == Brightness.dark;
    switch (key) {
      case 'blue':
        return isDark ? highlightBlueDark : highlightBlueLight;
      case 'pink':
        return isDark ? highlightPinkDark : highlightPinkLight;
      case 'green':
        return isDark ? highlightGreenDark : highlightGreenLight;
      case 'yellow':
      default:
        return isDark ? highlightYellowDark : highlightYellowLight;
    }
  }
}
