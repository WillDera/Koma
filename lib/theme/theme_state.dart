import 'package:flutter/material.dart';

import '../core/models/custom_font.dart';
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
    this.followSystemAccent = true,
    this.lightDynamicPrimary,
    this.darkDynamicPrimary,
    this.readingFont = ReadingFont.system,
    this.pageWidth = 680,
    this.textAlign = TextAlign.left,
    this.hyphenation = true,
    this.reducedMotion = false,
    this.defaultHighlight = 'yellow',
    this.handMode = HandMode.right,
    this.oneHandMode = false,
    this.bionicReading = false,
    this.amoledMode = false,
    this.customFonts = const [],
    this.uiFontId,
    this.readingFontId,
    this.showNsfwExtensions = false,
    this.showObsoleteExtensions = false,
    this.immersiveAutoHide = false,
    this.pageStyle = PageStyle.scroll,
  });

  final ThemeMode themeMode;
  final bool sepiaMode;
  final String fontFamily;
  final String? googleFont;
  final double fontSize;
  final double lineHeight;
  final AccentPreset accent;
  final String? customAccentHex;

  /// When true (default), accent comes from Material You / wallpaper colors.
  final bool followSystemAccent;

  /// Cached dynamic primaries from [DynamicColorBuilder] (not persisted).
  final Color? lightDynamicPrimary;
  final Color? darkDynamicPrimary;

  final ReadingFont readingFont;
  final double pageWidth;
  final TextAlign textAlign;
  final bool hyphenation;
  final bool reducedMotion;
  final String defaultHighlight;
  final HandMode handMode;
  final bool oneHandMode;
  final bool bionicReading;
  final bool amoledMode;

  /// User-imported font families (manifest from [CustomFontService]).
  final List<CustomFont> customFonts;

  /// When null, UI uses built-in Inter. Otherwise a [CustomFont.id].
  final String? uiFontId;

  /// When null, [readingFont] enum supplies the face. Otherwise a [CustomFont.id].
  final String? readingFontId;

  final bool showNsfwExtensions;
  final bool showObsoleteExtensions;
  final bool immersiveAutoHide;

  /// How the ebook reader lays out chapter text. Defaults to [PageStyle.scroll]
  /// so existing readers are unaffected until they opt in.
  final PageStyle pageStyle;

  // ── Derived getters ────────────────────────────────────────────────

  CustomFont? customFontById(String id) {
    for (final font in customFonts) {
      if (font.id == id) return font;
    }
    return null;
  }

  /// Resolved UI font family for [ThemeData].
  String get uiFontFamily {
    if (uiFontId != null) {
      return customFontById(uiFontId!)?.registeredFamily ?? AppType.uiFont;
    }
    return AppType.uiFont;
  }

  String get uiFontLabel {
    if (uiFontId != null) {
      return customFontById(uiFontId!)?.displayName ?? 'Custom';
    }
    return 'Inter';
  }

  String? get effectiveReadingFontFamily {
    if (readingFontId != null) {
      return customFontById(readingFontId!)?.registeredFamily;
    }
    return readingFont.googleFontFamily;
  }

  String get readingFontLabel {
    if (readingFontId != null) {
      return customFontById(readingFontId!)?.displayName ?? 'Custom';
    }
    return readingFont.label;
  }

  Color get accentColor {
    if (customAccentHex != null && customAccentHex!.isNotEmpty) {
      return resolveHex(customAccentHex!) ?? _fallbackAccent();
    }
    if (followSystemAccent) {
      final dynamicPrimary =
          isDarkMode ? darkDynamicPrimary : lightDynamicPrimary;
      return dynamicPrimary ?? _presetAccent(AccentPreset.indigo);
    }
    return _presetAccent(accent);
  }

  Color _fallbackAccent() => _presetAccent(accent);

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
    bool? followSystemAccent,
    Color? Function()? lightDynamicPrimary,
    Color? Function()? darkDynamicPrimary,
    ReadingFont? readingFont,
    double? pageWidth,
    TextAlign? textAlign,
    bool? hyphenation,
    bool? reducedMotion,
    String? defaultHighlight,
    HandMode? handMode,
    bool? oneHandMode,
    bool? bionicReading,
    bool? amoledMode,
    List<CustomFont>? customFonts,
    String? Function()? uiFontId,
    String? Function()? readingFontId,
    bool? showNsfwExtensions,
    bool? showObsoleteExtensions,
    bool? immersiveAutoHide,
    PageStyle? pageStyle,
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
      followSystemAccent: followSystemAccent ?? this.followSystemAccent,
      lightDynamicPrimary: lightDynamicPrimary != null
          ? lightDynamicPrimary()
          : this.lightDynamicPrimary,
      darkDynamicPrimary: darkDynamicPrimary != null
          ? darkDynamicPrimary()
          : this.darkDynamicPrimary,
      readingFont: readingFont ?? this.readingFont,
      pageWidth: pageWidth ?? this.pageWidth,
      textAlign: textAlign ?? this.textAlign,
      hyphenation: hyphenation ?? this.hyphenation,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      defaultHighlight: defaultHighlight ?? this.defaultHighlight,
      handMode: handMode ?? this.handMode,
      oneHandMode: oneHandMode ?? this.oneHandMode,
      bionicReading: bionicReading ?? this.bionicReading,
      amoledMode: amoledMode ?? this.amoledMode,
      customFonts: customFonts ?? this.customFonts,
      uiFontId: uiFontId != null ? uiFontId() : this.uiFontId,
      readingFontId: readingFontId != null ? readingFontId() : this.readingFontId,
      showNsfwExtensions: showNsfwExtensions ?? this.showNsfwExtensions,
      showObsoleteExtensions:
          showObsoleteExtensions ?? this.showObsoleteExtensions,
      immersiveAutoHide: immersiveAutoHide ?? this.immersiveAutoHide,
      pageStyle: pageStyle ?? this.pageStyle,
    );
  }
}

enum HandMode { left, right }

/// How the ebook reader presents a chapter.
///
/// [scroll] is the long-standing continuous scroll view. [curl] paginates the
/// chapter and turns pages with an interactive curl.
///
/// Curl is hidden from the UI for now ([kPageCurlUiEnabled]). The enum, prefs,
/// and paginated reader stay so we can restore the picker without a rewrite.
const bool kPageCurlUiEnabled = false;

enum PageStyle {
  scroll(label: 'Scroll'),
  curl(label: 'Curl');

  const PageStyle({required this.label});

  final String label;
}

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
