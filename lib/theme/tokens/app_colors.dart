import 'package:flutter/material.dart';

/// Koma design tokens — colors.
///
/// Three modes (light, dark, sepia) with one violet anchor (Figma "ReadLoom"
/// palette). Cool neutral surfaces tuned for long reading sessions without
/// fatigue. No pure white, no pure black.
class AppColors {
  AppColors._();

  // ─── Light (Figma cool paper — #f5f5fa family) ────────────────────────
  static const Color lightBg = Color(0xFFF5F5FA);
  static const Color lightBgElevated = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFE8E8F0);
  /// Header icon button well / cover placeholder (Figma `#e8e8f0` / `#e0e0ec`).
  static const Color lightIconWell = Color(0xFFE8E8F0);
  static const Color lightCoverPlaceholder = Color(0xFFE0E0EC);
  static const Color lightBorder = Color(0xFFE2E2EA);
  static const Color lightBorderStrong = Color(0xFFCFCFDD);
  static const Color lightTextPrimary = Color(0xFF12121A);
  static const Color lightTextSecondary = Color(0xFF7070A0);
  static const Color lightTextTertiary = Color(0xFFA0A0C0);
  static const Color lightAccent = Color(0xFF7857FF);
  static const Color lightAccentMuted = Color(0xFFEDE9FF);
  static const Color lightAccentText = Color(0xFFFFFFFF);
  static const Color lightOnAccent = Color(0xFFFFFFFF);

  // ─── Dark (Figma cool charcoal — #0c0c11 family) ──────────────────────
  static const Color darkBg = Color(0xFF0C0C11);
  static const Color darkBgElevated = Color(0xFF12121A);
  static const Color darkSurface = Color(0xFF16161F);
  // Segment track / muted fills (#1a1a24). Icon wells / cover fill use iconWell.
  static const Color darkSurfaceMuted = Color(0xFF1A1A24);
  static const Color darkIconWell = Color(0xFF1E1E2A);
  static const Color darkBorder = Color(0xFF24242E);
  static const Color darkBorderStrong = Color(0xFF2E2E3A);
  static const Color darkTextPrimary = Color(0xFFF0F0F8);
  static const Color darkTextSecondary = Color(0xFF8888A0);
  static const Color darkTextTertiary = Color(0xFF707088);
  // Figma keeps #7857ff in dark mode for active tabs / progress.
  static const Color darkAccent = Color(0xFF7857FF);
  static const Color darkAccentMuted = Color(0xFF261E44);
  static const Color darkAccentText = Color(0xFF0C0C11);
  static const Color darkOnAccent = Color(0xFFFFFFFF);

  // ─── AMOLED (true black) ──────────────────────────────────────────────
  static const Color amoledBg = Color(0xFF000000);
  static const Color amoledBgElevated = Color(0xFF0A0A0A);
  static const Color amoledSurface = Color(0xFF000000);
  static const Color amoledSurfaceMuted = Color(0xFF111111);
  static const Color amoledIconWell = Color(0xFF1A1A1A);
  static const Color amoledBorder = Color(0xFF222222);
  static const Color amoledBorderStrong = Color(0xFF333333);
  static const Color amoledTextPrimary = Color(0xFFF0F0F8);
  static const Color amoledTextSecondary = Color(0xFF8888A0);
  static const Color amoledTextTertiary = Color(0xFF707088);
  static const Color amoledAccent = Color(0xFF7857FF);
  static const Color amoledAccentMuted = Color(0xFF261E44);
  static const Color amoledAccentText = Color(0xFF0C0C11);
  static const Color amoledOnAccent = Color(0xFFFFFFFF);

  // ─── Sepia (paper) ─────────────────────────────────────────────────────
  static const Color sepiaBg = Color(0xFFF2E8D5);
  static const Color sepiaBgElevated = Color(0xFFF8EFDD);
  static const Color sepiaSurface = Color(0xFFFCF5E4);
  static const Color sepiaSurfaceMuted = Color(0xFFE9DCC2);
  static const Color sepiaIconWell = Color(0xFFE9DCC2);
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
  // Marker ink: saturated enough to read as a highlighter, not a tint.
  static const Color highlightYellowLight = Color(0xFFFFD54F);
  static const Color highlightBlueLight = Color(0xFF64B5F6);
  static const Color highlightPinkLight = Color(0xFFFF80AB);
  static const Color highlightGreenLight = Color(0xFF81C784);

  static const Color highlightYellowDark = Color(0xFFFFC107);
  static const Color highlightBlueDark = Color(0xFF448AFF);
  static const Color highlightPinkDark = Color(0xFFFF4081);
  static const Color highlightGreenDark = Color(0xFF66BB6A);

  static const Color highlightYellowSepia = Color(0xFFFFC14D);
  static const Color highlightBlueSepia = Color(0xFF7EABD4);
  static const Color highlightPinkSepia = Color(0xFFE8899A);
  static const Color highlightGreenSepia = Color(0xFF8FBF6A);

  /// Background wash over reading text. Higher than the old 0.35 so the
  /// marker actually shows; still translucent enough to keep glyphs readable.
  static const double highlightWashAlpha = 0.5;

  /// [highlight] at [highlightWashAlpha] for TextStyle / canvas fills.
  static Color highlightWash(
    String key,
    Brightness brightness, {
    bool isSepia = false,
  }) {
    return highlight(
      key,
      brightness,
      isSepia: isSepia,
    ).withValues(alpha: highlightWashAlpha);
  }

  // ─── Glass surface tints (used by sheets with blur) ───────────────────
  static const Color glassLight = Color(0xCCFFFFFF);
  static const Color glassDark = Color(0xCC16161F);
  static const Color glassSepia = Color(0xCCF8EFDD);

  // ─── Figma section hues (settings tiles, section labels, type badges) ─
  static const Color figmaViolet = Color(0xFF7857FF);
  static const Color figmaVioletLight = Color(0xFF9B7CFF);
  static const Color figmaGreen = Color(0xFF22C55E);
  static const Color figmaAmber = Color(0xFFF59E0B);
  static const Color figmaCyan = Color(0xFF22D3EE);
  static const Color figmaRose = Color(0xFFF43F5E);

  // ─── Accent presets (Settings → Accent color) ─────────────────────────
  static const Color accentIndigo = Color(0xFF7857FF);
  static const Color accentIndigoDark = Color(0xFF7857FF);
  static const Color accentAmber = Color(0xFFB07D52);
  static const Color accentAmberDark = Color(0xFFD4A277);
  static const Color accentForest = Color(0xFF4F7A55);
  static const Color accentForestDark = Color(0xFF7AAE82);

  // ─── Aethelgard "Electric Blue" accent (Cinematic Neo-Noir redesign) ──
  // The primary glow color from the Aethelgard design system. Used for
  // active states, FABs, and iconography when the aethelgard preset is
  // selected. #d9e2ff (light) / #afc6ff (dim/container).
  static const Color aethelgardPrimary = Color(0xFFD9E2FF);
  static const Color aethelgardPrimaryDim = Color(0xFFAFC6FF);
  static const Color aethelgardOnPrimary = Color(0xFF152F5E);

  // Dark-mode variant: the glow itself becomes the accent.
  static const Color aethelgardPrimaryDark = Color(0xFFAFC6FF);
  static const Color aethelgardOnPrimaryDark = Color(0xFF1A1815);

  /// Returns the appropriate highlight color for the given triple key
  /// (one of 'yellow' | 'blue' | 'pink' | 'green') for the given brightness.
  static Color highlight(
    String key,
    Brightness brightness, {
    bool isSepia = false,
  }) {
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
