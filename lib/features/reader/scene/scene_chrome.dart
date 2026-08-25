import 'package:flutter/material.dart';

/// Presentation chrome from a compiled `.koma` scene (Level 2).
///
/// Text still paints in Flutter. Particles/fog/timelines stay inert.
class SceneChrome {
  const SceneChrome({
    required this.environmentKind,
    this.background,
    this.ambient,
    this.ambientIntensity = 0.85,
    this.frost = 0,
    this.fade = const Duration(milliseconds: 600),
  });

  final String environmentKind;
  final Color? background;
  final Color? ambient;
  final double ambientIntensity;
  final double frost;
  final Duration fade;

  /// Default compiler theme is white/black — do not fight the user's page.
  bool get hasAuthoredBackground {
    final bg = background;
    if (bg == null) return false;
    final rgb = bg.toARGB32() & 0x00FFFFFF;
    return rgb != 0x00FFFFFF && rgb != 0x000000;
  }

  /// Frost veil over the page (behind glyphs). Capped for readability.
  double get frostOverlayAlpha => frost.clamp(0.0, 1.0) * 0.14;

  /// Ambient grade only when the scene authored a non-default page color.
  double get ambientOverlayAlpha {
    if (!hasAuthoredBackground) return 0;
    return (1.0 - ambientIntensity).clamp(0.0, 1.0) * 0.22;
  }

  /// Use the scene page only when it matches the user's light/dark preference.
  static Color pageBackground(
    SceneChrome? chrome,
    Color userBg, {
    required bool userDark,
  }) {
    if (chrome == null || !chrome.hasAuthoredBackground) return userBg;
    final bg = chrome.background!;
    final sceneDark =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
    if (sceneDark != userDark) return userBg;
    return bg;
  }

  static Duration switchDuration(
    SceneChrome? chrome,
    Duration fallback, {
    required bool disableAnimations,
  }) {
    if (disableAnimations) return Duration.zero;
    return chrome?.fade ?? fallback;
  }

  /// Parse `#RGB`, `#RRGGBB`, or `#RRGGBBAA`.
  static Color? tryParseHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      final r = s[0], g = s[1], b = s[2];
      s = '$r$r$g$g$b$b';
    }
    if (s.length == 6) {
      s = 'FF$s';
    } else if (s.length == 8) {
      // CSS `#RRGGBBAA` → Flutter `AARRGGBB`.
      s = '${s.substring(6, 8)}${s.substring(0, 6)}';
    } else {
      return null;
    }
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}
