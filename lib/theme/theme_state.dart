import 'package:flutter/material.dart';

import 'tokens/app_colors.dart';
import 'tokens/app_type.dart';

/// Immutable snapshot of all theme + typography preferences.
///
/// Consumed via `ref.watch(themeProvider)` — every field change triggers
/// a rebuild.  Mutations go through `ref.read(themeProvider.notifier)`.
class ThemeState {
  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.sepiaMode = false,
    this.fontFamily = AppType.uiFont,
    this.googleFont,
    this.fontSize = 17.0,
    this.lineHeight = 1.65,
    this.accent = AccentPreset.indigo,
    this.customAccentHex,
    this.readingFont = ReadingFont.literata,
    this.pageWidth = 680,
    this.textAlign = TextAlign.left,
    this.hyphenation = true,
    this.reducedMotion = false,
    this.defaultHighlight = 'yellow',
    this.handMode = HandMode.right,
    this.oneHandMode = false,
    this.bionicReading = false,
    this.useDeviceFont = false,
    this.amoledMode = false,
    this.systemFontFamily,
    this.showNsfwExtensions = false,
    this.showObsoleteExtensions = false,
  });

  final ThemeMode themeMode;
  final bool sepiaMode;
  final String fontFamily;
  final String? googleFont;
  final double fontSize;
  final double lineHeight;
  final AccentPreset accent;
  final String? customAccentHex;
  final ReadingFont readingFont;
  final double pageWidth;
  final TextAlign textAlign;
  final bool hyphenation;
  final bool reducedMotion;
  final String defaultHighlight;
  final HandMode handMode;
  final bool oneHandMode;
  final bool bionicReading;
  final bool useDeviceFont;
  final bool amoledMode;
  final String? systemFontFamily;
  final bool showNsfwExtensions;
  final bool showObsoleteExtensions;

  // ── Derived getters ────────────────────────────────────────────────

  Color get accentColor {
    if (customAccentHex != null && customAccentHex!.isNotEmpty) {
      return resolveHex(customAccentHex!) ?? _presetAccent(accent);
    }
    return _presetAccent(accent);
  }

  Color _presetAccent(AccentPreset preset) {
    if (sepiaMode) return AppColors.sepiaAccent;
    final dark = isDarkMode;
    switch (preset) {
      case AccentPreset.indigo:
        return dark ? AppColors.accentIndigoDark : AppColors.accentIndigo;
      case AccentPreset.amber:
        return dark ? AppColors.accentAmberDark : AppColors.accentAmber;
      case AccentPreset.forest:
        return dark ? AppColors.accentForestDark : AppColors.accentForest;
      case AccentPreset.aethelgard:
        return dark
            ? AppColors.aethelgardPrimaryDark
            : AppColors.aethelgardPrimary;
    }
  }

  static Color? resolveHex(String hex) {
    var v = hex.trim();
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final i = int.tryParse(v, radix: 16);
    if (i == null) return null;
    return Color(i);
  }

  Color get bgColor {
    if (sepiaMode) return AppColors.sepiaBg;
    return isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  }

  String? get readingFontFamily => readingFont.googleFontFamily;

  FontWeight get bionicBoldWeight => FontWeight.w700;

  double get bionicBoldFraction => 0.4;

  bool get isDarkMode =>
      themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  bool get isDark => isDarkMode;
  bool get isSepia => sepiaMode;

  // ── Copy-with ──────────────────────────────────────────────────────

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? sepiaMode,
    String? fontFamily,
    String? Function()? googleFont,
    double? fontSize,
    double? lineHeight,
    AccentPreset? accent,
    String? Function()? customAccentHex,
    ReadingFont? readingFont,
    double? pageWidth,
    TextAlign? textAlign,
    bool? hyphenation,
    bool? reducedMotion,
    String? defaultHighlight,
    HandMode? handMode,
    bool? oneHandMode,
      bool? bionicReading,
      bool? useDeviceFont,
      bool? amoledMode,
      String? systemFontFamily,
      bool? showNsfwExtensions,
      bool? showObsoleteExtensions,
    }) {
      return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      sepiaMode: sepiaMode ?? this.sepiaMode,
      fontFamily: fontFamily ?? this.fontFamily,
      googleFont: googleFont != null ? googleFont() : this.googleFont,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      accent: accent ?? this.accent,
      customAccentHex: customAccentHex != null
          ? customAccentHex()
          : this.customAccentHex,
      readingFont: readingFont ?? this.readingFont,
      pageWidth: pageWidth ?? this.pageWidth,
      textAlign: textAlign ?? this.textAlign,
      hyphenation: hyphenation ?? this.hyphenation,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      defaultHighlight: defaultHighlight ?? this.defaultHighlight,
      handMode: handMode ?? this.handMode,
      oneHandMode: oneHandMode ?? this.oneHandMode,
      bionicReading: bionicReading ?? this.bionicReading,
      useDeviceFont: useDeviceFont ?? this.useDeviceFont,
      amoledMode: amoledMode ?? this.amoledMode,
      systemFontFamily: systemFontFamily ?? this.systemFontFamily,
      showNsfwExtensions: showNsfwExtensions ?? this.showNsfwExtensions,
      showObsoleteExtensions: showObsoleteExtensions ?? this.showObsoleteExtensions,
    );
  }
}

enum HandMode { left, right }

enum AccentPreset { indigo, amber, forest, aethelgard }

/// Reading fonts the user can choose from.
enum ReadingFont {
  system(label: 'System'),
  literata(label: 'Literata', googleFontFamily: 'Literata'),
  inter(label: 'Inter', googleFontFamily: 'Inter'),
  lora(label: 'Lora', googleFontFamily: 'Lora'),
  merriweather(label: 'Merriweather', googleFontFamily: 'Merriweather'),
  sourceSerif(label: 'Source Serif 4', googleFontFamily: 'Source Serif 4'),
  crimsonPro(label: 'Crimson Pro', googleFontFamily: 'Crimson Pro');

  const ReadingFont({required this.label, this.googleFontFamily});
  final String label;
  final String? googleFontFamily;
}
