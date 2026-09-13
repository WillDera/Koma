import 'package:flutter/material.dart';

import 'theme_palette.dart';

/// Catalog of community color themes available in Settings → Appearance.
class ThemePacks {
  ThemePacks._();

  static const List<String> familyOrder = [
    'Koma',
    'Catppuccin',
    'Gruvbox',
    'Black Metal',
    'Rosé Pine',
    'Kanagawa',
    'Tokyo Night',
  ];

  static final List<ThemePack> all = [
    koma,
    ...catppuccin,
    ...gruvbox,
    ...blackMetal,
    ...rosePine,
    ...kanagawa,
    ...tokyoNight,
  ];

  static final Map<String, ThemePack> byId = {
    for (final pack in all) pack.id: pack,
  };

  static ThemePack? tryGet(String? id) {
    if (id == null || id.isEmpty) return null;
    return byId[id];
  }

  static List<ThemePack> forFamily(String family) =>
      all.where((p) => p.family == family).toList(growable: false);

  /// Same family, opposite brightness — e.g. Latte ↔ Mocha for system mode.
  static ThemePack? sibling(ThemePack pack, Brightness brightness) {
    if (pack.brightness == brightness) return pack;
    for (final other in all) {
      if (other.family == pack.family && other.brightness == brightness) {
        return other;
      }
    }
    return null;
  }

  // ── Koma (default) ───────────────────────────────────────────────────

  static final ThemePack koma = ThemePack(
    id: kDefaultThemePackId,
    family: 'Koma',
    variant: 'Default',
    palette: ThemePalette(
      brightness: Brightness.light,
      bg: const Color(0xFFF5F5FA),
      bgElevated: const Color(0xFFFFFFFF),
      surface: const Color(0xFFFFFFFF),
      surfaceMuted: const Color(0xFFE8E8F0),
      iconWell: const Color(0xFFE8E8F0),
      border: const Color(0xFFE2E2EA),
      borderStrong: const Color(0xFFCFCFDD),
      textPrimary: const Color(0xFF12121A),
      textSecondary: const Color(0xFF7070A0),
      textTertiary: const Color(0xFFA0A0C0),
      accent: const Color(0xFF9852FF),
      accentMuted: const Color(0xFFEDE9FF),
      onAccent: const Color(0xFFFFFFFF),
    ),
  );

  // Koma dark is not a separate pack id — default dark/AMOLED still come from
  // AppColors when themePackId is koma / null. Pack id "koma" means brand
  // light+dark tokens, not a forced light surface.

  // ── Catppuccin ───────────────────────────────────────────────────────

  static final List<ThemePack> catppuccin = [
    _pack(
      id: 'catppuccin_latte',
      family: 'Catppuccin',
      variant: 'Latte',
      brightness: Brightness.light,
      bg: const Color(0xFFEFF1F5),
      bgElevated: const Color(0xFFE6E9EF),
      surface: const Color(0xFFFFFFFF),
      surfaceMuted: const Color(0xFFCCD0DA),
      iconWell: const Color(0xFFCCD0DA),
      border: const Color(0xFFBCC0CC),
      borderStrong: const Color(0xFF9CA0B0),
      textPrimary: const Color(0xFF4C4F69),
      textSecondary: const Color(0xFF6C6F85),
      textTertiary: const Color(0xFF9CA0B0),
      accent: const Color(0xFF8839EF),
    ),
    _pack(
      id: 'catppuccin_frappe',
      family: 'Catppuccin',
      variant: 'Frappé',
      brightness: Brightness.dark,
      bg: const Color(0xFF303446),
      bgElevated: const Color(0xFF292C3C),
      surface: const Color(0xFF292C3C),
      surfaceMuted: const Color(0xFF414559),
      iconWell: const Color(0xFF414559),
      border: const Color(0xFF51576D),
      borderStrong: const Color(0xFF626880),
      textPrimary: const Color(0xFFC6D0F5),
      textSecondary: const Color(0xFFA5ADCE),
      textTertiary: const Color(0xFF737994),
      accent: const Color(0xFFCA9EE6),
    ),
    _pack(
      id: 'catppuccin_macchiato',
      family: 'Catppuccin',
      variant: 'Macchiato',
      brightness: Brightness.dark,
      bg: const Color(0xFF24273A),
      bgElevated: const Color(0xFF1E2030),
      surface: const Color(0xFF1E2030),
      surfaceMuted: const Color(0xFF363A4F),
      iconWell: const Color(0xFF363A4F),
      border: const Color(0xFF494D64),
      borderStrong: const Color(0xFF5B6078),
      textPrimary: const Color(0xFFCAD3F5),
      textSecondary: const Color(0xFFA5ADCB),
      textTertiary: const Color(0xFF6E738D),
      accent: const Color(0xFFC6A0F6),
    ),
    _pack(
      id: 'catppuccin_mocha',
      family: 'Catppuccin',
      variant: 'Mocha',
      brightness: Brightness.dark,
      bg: const Color(0xFF1E1E2E),
      bgElevated: const Color(0xFF181825),
      surface: const Color(0xFF181825),
      surfaceMuted: const Color(0xFF313244),
      iconWell: const Color(0xFF313244),
      border: const Color(0xFF45475A),
      borderStrong: const Color(0xFF585B70),
      textPrimary: const Color(0xFFCDD6F4),
      textSecondary: const Color(0xFFBAC2DE),
      textTertiary: const Color(0xFF6C7086),
      accent: const Color(0xFFCBA6F7),
    ),
  ];

  // ── Gruvbox ──────────────────────────────────────────────────────────

  static final List<ThemePack> gruvbox = [
    _pack(
      id: 'gruvbox_dark_hard',
      family: 'Gruvbox',
      variant: 'Dark Hard',
      brightness: Brightness.dark,
      bg: const Color(0xFF1D2021),
      bgElevated: const Color(0xFF282828),
      surface: const Color(0xFF282828),
      surfaceMuted: const Color(0xFF3C3836),
      iconWell: const Color(0xFF3C3836),
      border: const Color(0xFF504945),
      borderStrong: const Color(0xFF665C54),
      textPrimary: const Color(0xFFEBDBB2),
      textSecondary: const Color(0xFFD5C4A1),
      textTertiary: const Color(0xFF928374),
      accent: const Color(0xFFFE8019),
    ),
    _pack(
      id: 'gruvbox_dark_medium',
      family: 'Gruvbox',
      variant: 'Dark Medium',
      brightness: Brightness.dark,
      bg: const Color(0xFF282828),
      bgElevated: const Color(0xFF32302F),
      surface: const Color(0xFF32302F),
      surfaceMuted: const Color(0xFF3C3836),
      iconWell: const Color(0xFF3C3836),
      border: const Color(0xFF504945),
      borderStrong: const Color(0xFF665C54),
      textPrimary: const Color(0xFFEBDBB2),
      textSecondary: const Color(0xFFD5C4A1),
      textTertiary: const Color(0xFF928374),
      accent: const Color(0xFFFE8019),
    ),
    _pack(
      id: 'gruvbox_dark_soft',
      family: 'Gruvbox',
      variant: 'Dark Soft',
      brightness: Brightness.dark,
      bg: const Color(0xFF32302F),
      bgElevated: const Color(0xFF3C3836),
      surface: const Color(0xFF3C3836),
      surfaceMuted: const Color(0xFF504945),
      iconWell: const Color(0xFF504945),
      border: const Color(0xFF665C54),
      borderStrong: const Color(0xFF7C6F64),
      textPrimary: const Color(0xFFEBDBB2),
      textSecondary: const Color(0xFFD5C4A1),
      textTertiary: const Color(0xFFA89984),
      accent: const Color(0xFFFE8019),
    ),
    _pack(
      id: 'gruvbox_light_hard',
      family: 'Gruvbox',
      variant: 'Light Hard',
      brightness: Brightness.light,
      bg: const Color(0xFFF9F5D7),
      bgElevated: const Color(0xFFFBF1C7),
      surface: const Color(0xFFFBF1C7),
      surfaceMuted: const Color(0xFFEBDBB2),
      iconWell: const Color(0xFFEBDBB2),
      border: const Color(0xFFD5C4A1),
      borderStrong: const Color(0xFFBDAE93),
      textPrimary: const Color(0xFF3C3836),
      textSecondary: const Color(0xFF504945),
      textTertiary: const Color(0xFF7C6F64),
      accent: const Color(0xFFAF3A03),
    ),
    _pack(
      id: 'gruvbox_light_medium',
      family: 'Gruvbox',
      variant: 'Light Medium',
      brightness: Brightness.light,
      bg: const Color(0xFFFBF1C7),
      bgElevated: const Color(0xFFF2E5BC),
      surface: const Color(0xFFF2E5BC),
      surfaceMuted: const Color(0xFFEBDBB2),
      iconWell: const Color(0xFFEBDBB2),
      border: const Color(0xFFD5C4A1),
      borderStrong: const Color(0xFFBDAE93),
      textPrimary: const Color(0xFF3C3836),
      textSecondary: const Color(0xFF504945),
      textTertiary: const Color(0xFF7C6F64),
      accent: const Color(0xFFAF3A03),
    ),
    _pack(
      id: 'gruvbox_light_soft',
      family: 'Gruvbox',
      variant: 'Light Soft',
      brightness: Brightness.light,
      bg: const Color(0xFFF2E5BC),
      bgElevated: const Color(0xFFEBDBB2),
      surface: const Color(0xFFEBDBB2),
      surfaceMuted: const Color(0xFFD5C4A1),
      iconWell: const Color(0xFFD5C4A1),
      border: const Color(0xFFBDAE93),
      borderStrong: const Color(0xFFA89984),
      textPrimary: const Color(0xFF3C3836),
      textSecondary: const Color(0xFF504945),
      textTertiary: const Color(0xFF7C6F64),
      accent: const Color(0xFFAF3A03),
    ),
  ];

  // ── Black Metal (base16-black-metal family) ───────────────────────────

  static final List<ThemePack> blackMetal = [
    _blackMetal(
      id: 'black_metal',
      variant: 'Black Metal',
      accent: const Color(0xFF5F8787),
    ),
    _blackMetal(
      id: 'black_metal_bathory',
      variant: 'Bathory',
      accent: const Color(0xFF5F8787),
      highlight: const Color(0xFFE78A53),
    ),
    _blackMetal(
      id: 'black_metal_burzum',
      variant: 'Burzum',
      accent: const Color(0xFF99BBA3),
      highlight: const Color(0xFFDDCB8C),
    ),
    _blackMetal(
      id: 'black_metal_dark_funeral',
      variant: 'Dark Funeral',
      accent: const Color(0xFF5F81A5),
      highlight: const Color(0xFFD75F5F),
    ),
    _blackMetal(
      id: 'black_metal_gorgoroth',
      variant: 'Gorgoroth',
      accent: const Color(0xFF8C7F70),
      highlight: const Color(0xFF9B8D7F),
    ),
    _blackMetal(
      id: 'black_metal_immortal',
      variant: 'Immortal',
      accent: const Color(0xFF556677),
      highlight: const Color(0xFF7799BB),
    ),
    _blackMetal(
      id: 'black_metal_khold',
      variant: 'Khold',
      accent: const Color(0xFF974B46),
      highlight: const Color(0xFFC47862),
    ),
    _blackMetal(
      id: 'black_metal_marduk',
      variant: 'Marduk',
      accent: const Color(0xFF626B67),
      highlight: const Color(0xFF8C8C8C),
    ),
    _blackMetal(
      id: 'black_metal_mayhem',
      variant: 'Mayhem',
      accent: const Color(0xFFE78A53),
      highlight: const Color(0xFFF3ECD4),
    ),
    _blackMetal(
      id: 'black_metal_nile',
      variant: 'Nile',
      accent: const Color(0xFF777755),
      highlight: const Color(0xFFAAAA77),
    ),
    _blackMetal(
      id: 'black_metal_venom',
      variant: 'Venom',
      accent: const Color(0xFF79241F),
      highlight: const Color(0xFFCF8772),
    ),
  ];

  // ── Rosé Pine ────────────────────────────────────────────────────────

  static final List<ThemePack> rosePine = [
    _pack(
      id: 'rose_pine',
      family: 'Rosé Pine',
      variant: 'Main',
      brightness: Brightness.dark,
      bg: const Color(0xFF191724),
      bgElevated: const Color(0xFF1F1D2E),
      surface: const Color(0xFF1F1D2E),
      surfaceMuted: const Color(0xFF26233A),
      iconWell: const Color(0xFF26233A),
      border: const Color(0xFF403D52),
      borderStrong: const Color(0xFF524F67),
      textPrimary: const Color(0xFFE0DEF4),
      textSecondary: const Color(0xFF908CAA),
      textTertiary: const Color(0xFF6E6A86),
      accent: const Color(0xFFC4A7E7),
    ),
    _pack(
      id: 'rose_pine_moon',
      family: 'Rosé Pine',
      variant: 'Moon',
      brightness: Brightness.dark,
      bg: const Color(0xFF232136),
      bgElevated: const Color(0xFF2A273F),
      surface: const Color(0xFF2A273F),
      surfaceMuted: const Color(0xFF393552),
      iconWell: const Color(0xFF393552),
      border: const Color(0xFF44415A),
      borderStrong: const Color(0xFF56526E),
      textPrimary: const Color(0xFFE0DEF4),
      textSecondary: const Color(0xFF908CAA),
      textTertiary: const Color(0xFF6E6A86),
      accent: const Color(0xFFC4A7E7),
    ),
    _pack(
      id: 'rose_pine_dawn',
      family: 'Rosé Pine',
      variant: 'Dawn',
      brightness: Brightness.light,
      bg: const Color(0xFFFAF4ED),
      bgElevated: const Color(0xFFFFFAF3),
      surface: const Color(0xFFFFFAF3),
      surfaceMuted: const Color(0xFFF2E9E1),
      iconWell: const Color(0xFFF2E9E1),
      border: const Color(0xFFDFDAD9),
      borderStrong: const Color(0xFFCECACD),
      textPrimary: const Color(0xFF575279),
      textSecondary: const Color(0xFF797593),
      textTertiary: const Color(0xFF9893A5),
      accent: const Color(0xFF907AA9),
    ),
  ];

  // ── Kanagawa ─────────────────────────────────────────────────────────

  static final List<ThemePack> kanagawa = [
    _pack(
      id: 'kanagawa_wave',
      family: 'Kanagawa',
      variant: 'Wave',
      brightness: Brightness.dark,
      bg: const Color(0xFF1F1F28),
      bgElevated: const Color(0xFF2A2A37),
      surface: const Color(0xFF2A2A37),
      surfaceMuted: const Color(0xFF363646),
      iconWell: const Color(0xFF363646),
      border: const Color(0xFF54546D),
      borderStrong: const Color(0xFF727169),
      textPrimary: const Color(0xFFDCD7BA),
      textSecondary: const Color(0xFFC8C093),
      textTertiary: const Color(0xFF727169),
      accent: const Color(0xFF7E9CD8),
    ),
    _pack(
      id: 'kanagawa_dragon',
      family: 'Kanagawa',
      variant: 'Dragon',
      brightness: Brightness.dark,
      bg: const Color(0xFF181616),
      bgElevated: const Color(0xFF1D1C19),
      surface: const Color(0xFF1D1C19),
      surfaceMuted: const Color(0xFF282727),
      iconWell: const Color(0xFF282727),
      border: const Color(0xFF393836),
      borderStrong: const Color(0xFF625E5A),
      textPrimary: const Color(0xFFC5C9C5),
      textSecondary: const Color(0xFFA6A69C),
      textTertiary: const Color(0xFF727169),
      accent: const Color(0xFF8BA4B0),
    ),
    _pack(
      id: 'kanagawa_lotus',
      family: 'Kanagawa',
      variant: 'Lotus',
      brightness: Brightness.light,
      bg: const Color(0xFFF2ECBC),
      bgElevated: const Color(0xFFE7DAB5),
      surface: const Color(0xFFE7DAB5),
      surfaceMuted: const Color(0xFFE4D794),
      iconWell: const Color(0xFFE4D794),
      border: const Color(0xFFD5CEA3),
      borderStrong: const Color(0xFFA09CAC),
      textPrimary: const Color(0xFF545464),
      textSecondary: const Color(0xFF5C5870),
      textTertiary: const Color(0xFF8A8980),
      accent: const Color(0xFF624C83),
    ),
  ];

  // ── Tokyo Night ──────────────────────────────────────────────────────

  static final List<ThemePack> tokyoNight = [
    _pack(
      id: 'tokyo_night',
      family: 'Tokyo Night',
      variant: 'Night',
      brightness: Brightness.dark,
      bg: const Color(0xFF1A1B26),
      bgElevated: const Color(0xFF16161E),
      surface: const Color(0xFF16161E),
      surfaceMuted: const Color(0xFF24283B),
      iconWell: const Color(0xFF24283B),
      border: const Color(0xFF292E42),
      borderStrong: const Color(0xFF414868),
      textPrimary: const Color(0xFFC0CAF5),
      textSecondary: const Color(0xFFA9B1D6),
      textTertiary: const Color(0xFF565F89),
      accent: const Color(0xFF7AA2F7),
    ),
    _pack(
      id: 'tokyo_night_storm',
      family: 'Tokyo Night',
      variant: 'Storm',
      brightness: Brightness.dark,
      bg: const Color(0xFF24283B),
      bgElevated: const Color(0xFF1F2335),
      surface: const Color(0xFF1F2335),
      surfaceMuted: const Color(0xFF292E42),
      iconWell: const Color(0xFF292E42),
      border: const Color(0xFF3B4261),
      borderStrong: const Color(0xFF414868),
      textPrimary: const Color(0xFFC0CAF5),
      textSecondary: const Color(0xFFA9B1D6),
      textTertiary: const Color(0xFF565F89),
      accent: const Color(0xFF7AA2F7),
    ),
    _pack(
      id: 'tokyo_night_moon',
      family: 'Tokyo Night',
      variant: 'Moon',
      brightness: Brightness.dark,
      bg: const Color(0xFF222436),
      bgElevated: const Color(0xFF1E2030),
      surface: const Color(0xFF1E2030),
      surfaceMuted: const Color(0xFF2F334D),
      iconWell: const Color(0xFF2F334D),
      border: const Color(0xFF3B4261),
      borderStrong: const Color(0xFF545C7E),
      textPrimary: const Color(0xFFC8D3F5),
      textSecondary: const Color(0xFFA9B1D6),
      textTertiary: const Color(0xFF636DA6),
      accent: const Color(0xFF82AAFF),
    ),
    _pack(
      id: 'tokyo_night_day',
      family: 'Tokyo Night',
      variant: 'Day',
      brightness: Brightness.light,
      bg: const Color(0xFFE1E2E7),
      bgElevated: const Color(0xFFD5D6DB),
      surface: const Color(0xFFD5D6DB),
      surfaceMuted: const Color(0xFFC4C5CA),
      iconWell: const Color(0xFFC4C5CA),
      border: const Color(0xFFB4B5BA),
      borderStrong: const Color(0xFF9699A3),
      textPrimary: const Color(0xFF3760BF),
      textSecondary: const Color(0xFF6172B0),
      textTertiary: const Color(0xFF848CB5),
      accent: const Color(0xFF2E7DE9),
    ),
  ];

  // ── Helpers ──────────────────────────────────────────────────────────

  static ThemePack _pack({
    required String id,
    required String family,
    required String variant,
    required Brightness brightness,
    required Color bg,
    required Color bgElevated,
    required Color surface,
    required Color surfaceMuted,
    required Color iconWell,
    required Color border,
    required Color borderStrong,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color accent,
    Color? accentMuted,
    Color? onAccent,
  }) {
    return ThemePack(
      id: id,
      family: family,
      variant: variant,
      palette: ThemePalette(
        brightness: brightness,
        bg: bg,
        bgElevated: bgElevated,
        surface: surface,
        surfaceMuted: surfaceMuted,
        iconWell: iconWell,
        border: border,
        borderStrong: borderStrong,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        accent: accent,
        accentMuted: accentMuted ?? ThemePalette.mutedAccent(accent, surface),
        onAccent: onAccent ?? ThemePalette.onAccentFor(accent),
      ),
    );
  }

  static ThemePack _blackMetal({
    required String id,
    required String variant,
    required Color accent,
    Color? highlight,
  }) {
    final a = highlight ?? accent;
    return _pack(
      id: id,
      family: 'Black Metal',
      variant: variant,
      brightness: Brightness.dark,
      bg: const Color(0xFF000000),
      bgElevated: const Color(0xFF121212),
      surface: const Color(0xFF121212),
      surfaceMuted: const Color(0xFF222222),
      iconWell: const Color(0xFF222222),
      border: const Color(0xFF333333),
      borderStrong: const Color(0xFF444444),
      textPrimary: const Color(0xFFC1C1C1),
      textSecondary: const Color(0xFF999999),
      textTertiary: const Color(0xFF666666),
      accent: a,
    );
  }
}
