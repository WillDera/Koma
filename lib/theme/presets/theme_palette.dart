import 'package:flutter/material.dart';

/// Complete surface + accent tokens for one theme variant.
///
/// Fed into [AppTheme] so Material widgets and `context.colors` stay in sync.
@immutable
class ThemePalette {
  const ThemePalette({
    required this.brightness,
    required this.bg,
    required this.bgElevated,
    required this.surface,
    required this.surfaceMuted,
    required this.iconWell,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentMuted,
    required this.onAccent,
  });

  final Brightness brightness;
  final Color bg;
  final Color bgElevated;
  final Color surface;
  final Color surfaceMuted;
  final Color iconWell;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentMuted;
  final Color onAccent;

  /// Soft fill from [accent] over [surface] (chips, selected nav).
  static Color mutedAccent(Color accent, Color surface) =>
      Color.lerp(surface, accent, 0.14)!;

  static Color onAccentFor(Color accent) {
    final luminance = accent.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF1A1815) : Colors.white;
  }
}

/// One selectable app-wide look (family + variant).
@immutable
class ThemePack {
  const ThemePack({
    required this.id,
    required this.family,
    required this.variant,
    required this.palette,
  });

  /// Stable prefs key, e.g. `catppuccin_mocha`.
  final String id;

  /// Group label in Settings, e.g. `Catppuccin`.
  final String family;

  /// Variant label, e.g. `Mocha`.
  final String variant;

  final ThemePalette palette;

  String get label => '$family · $variant';

  Brightness get brightness => palette.brightness;

  bool get isDark => brightness == Brightness.dark;
}

/// Built-in Koma look — used when no community pack is selected.
const String kDefaultThemePackId = 'koma';
