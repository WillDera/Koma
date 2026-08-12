import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/custom_font.dart';
import '../core/services/custom_font_service.dart';
import 'app_theme.dart';
import 'theme_state.dart';
import 'tokens/app_type.dart';

export 'theme_state.dart';

/// Riverpod Notifier that manages theme + typography preferences.
///
/// State is an immutable [ThemeState]. Consumers read fields via
/// `ref.watch(themeProvider).fontSize` and call mutations via
/// `ref.read(themeProvider.notifier).setFontSize(x)`.
///
/// Persistence uses SharedPreferences (matches mangayomi's Isar Settings
/// pattern but scoped to the key-value pairs we actually use).
class ThemeNotifier extends Notifier<ThemeState> {
  final CustomFontService _fontService = CustomFontService.instance;

  static const _keyThemeMode = 'theme_mode';
  static const _keySepiaMode = 'sepia_mode';
  static const _keyFontFamily = 'font_family';
  static const _keyGoogleFont = 'google_font';
  static const _keyFontSize = 'font_size';
  static const _keyLineHeight = 'line_height';
  static const _keyAccentIndex = 'accent_index';
  static const _keyCustomAccentHex = 'custom_accent_hex';
  static const _keyFollowSystemAccent = 'follow_system_accent';
  static const _keyReadingFont = 'reading_font';
  static const _keyPageWidth = 'page_width';
  static const _keyTextAlign = 'text_align';
  static const _keyHyphenation = 'hyphenation';
  static const _keyReducedMotion = 'reduced_motion';
  static const _keyDefaultHighlight = 'default_highlight';
  static const _keyHandMode = 'hand_mode';
  static const _keyOneHandMode = 'one_hand_mode';
  static const _keyBionicReading = 'bionic_reading';
  static const _keyAmoledMode = 'amoled_mode';
  static const _keyUiFontId = 'ui_font_id';
  static const _keyReadingFontId = 'reading_font_id';
  static const _keyShowNsfwExtensions = 'show_nsfw_extensions';
  static const _keyShowObsoleteExtensions = 'show_obsolete_extensions';
  static const _keyImmersiveAutoHide = 'immersive_auto_hide';
  static const _keyPageStyle = 'page_style';

  /// Full Material You schemes from [DynamicColorBuilder] (not persisted).
  ColorScheme? lightDynamicScheme;
  ColorScheme? darkDynamicScheme;

  @override
  ThemeState build() {
    // Default state — init() is called from main.dart before first paint
    // to load persisted values.
    return const ThemeState();
  }

  /// Load persisted preferences from disk. Called once at startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final customFonts = await _fontService.listFonts();
    final uiFontId = _nonEmpty(prefs.getString(_keyUiFontId));
    final readingFontId = _nonEmpty(prefs.getString(_keyReadingFontId));

    state = ThemeState(
      themeMode: ThemeMode.values[prefs.getInt(_keyThemeMode) ?? 0],
      sepiaMode: prefs.getBool(_keySepiaMode) ?? false,
      fontFamily: prefs.getString(_keyFontFamily) ?? state.fontFamily,
      googleFont: _nonEmpty(prefs.getString(_keyGoogleFont)),
      fontSize: prefs.getDouble(_keyFontSize) ?? 17.0,
      lineHeight: prefs.getDouble(_keyLineHeight) ?? 1.65,
      accent: AccentPreset.values[prefs.getInt(_keyAccentIndex) ?? 0],
      customAccentHex: prefs.getString(_keyCustomAccentHex),
      followSystemAccent: prefs.getBool(_keyFollowSystemAccent) ?? true,
      readingFont: ReadingFont.values[prefs.getInt(_keyReadingFont) ?? 0],
      pageWidth: prefs.getDouble(_keyPageWidth) ?? 680,
      textAlign: TextAlign.values[prefs.getInt(_keyTextAlign) ?? 0],
      hyphenation: prefs.getBool(_keyHyphenation) ?? true,
      reducedMotion: prefs.getBool(_keyReducedMotion) ?? false,
      defaultHighlight: prefs.getString(_keyDefaultHighlight) ?? 'yellow',
      handMode: HandMode.values[prefs.getInt(_keyHandMode) ?? 1],
      oneHandMode: prefs.getBool(_keyOneHandMode) ?? false,
      bionicReading: prefs.getBool(_keyBionicReading) ?? false,
      amoledMode: prefs.getBool(_keyAmoledMode) ?? false,
      customFonts: customFonts,
      uiFontId: _validFontId(uiFontId, customFonts),
      readingFontId: _validFontId(readingFontId, customFonts),
      showNsfwExtensions: prefs.getBool(_keyShowNsfwExtensions) ?? false,
      showObsoleteExtensions:
          prefs.getBool(_keyShowObsoleteExtensions) ?? false,
      immersiveAutoHide: prefs.getBool(_keyImmersiveAutoHide) ?? false,
      pageStyle:
          PageStyle.values[(prefs.getInt(_keyPageStyle) ?? 0).clamp(
            0,
            PageStyle.values.length - 1,
          )],
    );

    await _ensureSelectedFontsLoaded();
  }

  static String? _nonEmpty(String? s) => s != null && s.isNotEmpty ? s : null;

  static String? _validFontId(String? id, List<CustomFont> catalog) {
    if (id == null) return null;
    for (final font in catalog) {
      if (font.id == id) return id;
    }
    return null;
  }

  Future<void> _ensureSelectedFontsLoaded() async {
    if (state.uiFontId != null) {
      await _fontService.ensureLoadedById(state.uiFontId!, state.customFonts);
    }
    if (state.readingFontId != null) {
      await _fontService.ensureLoadedById(
        state.readingFontId!,
        state.customFonts,
      );
    }
  }

  /// Called from [DynamicColorBuilder] whenever wallpaper/system colors change.
  void setDynamicColorSchemes(ColorScheme? light, ColorScheme? dark) {
    lightDynamicScheme = light;
    darkDynamicScheme = dark;
    final lp = light?.primary;
    final dp = dark?.primary;
    if (lp == state.lightDynamicPrimary && dp == state.darkDynamicPrimary) {
      return;
    }
    state = state.copyWith(
      lightDynamicPrimary: () => lp,
      darkDynamicPrimary: () => dp,
    );
  }

  // ── Theme convenience getters (forwarded from state) ───────────────

  ColorScheme? get _activeDynamicScheme {
    if (!state.followSystemAccent || state.customAccentHex != null) {
      return null;
    }
    return state.isDarkMode ? darkDynamicScheme : lightDynamicScheme;
  }

  ColorScheme? get _lightDynamicForTheme {
    if (!state.followSystemAccent || state.customAccentHex != null) {
      return null;
    }
    return lightDynamicScheme;
  }

  ColorScheme? get _darkDynamicForTheme {
    if (!state.followSystemAccent || state.customAccentHex != null) {
      return null;
    }
    return darkDynamicScheme;
  }

  /// Live light theme built from the current accent / Material You colors.
  ThemeData get lightTheme => AppTheme.lightTheme(
    accent: state.accentColor,
    fontFamily: state.uiFontFamily,
    dynamicScheme: _lightDynamicForTheme,
  );
  ThemeData get darkTheme => AppTheme.darkTheme(
    accent: state.accentColor,
    amoled: state.amoledMode,
    fontFamily: state.uiFontFamily,
    dynamicScheme: _darkDynamicForTheme,
  );
  ThemeData get sepiaTheme => AppTheme.sepiaTheme(
    accent: state.accentColor,
    fontFamily: state.uiFontFamily,
    dynamicScheme: _activeDynamicScheme,
  );

  ThemeData get currentTheme {
    if (state.sepiaMode) return sepiaTheme;
    if (state.isDark) return darkTheme;
    return lightTheme;
  }

  // ── Custom fonts ─────────────────────────────────────────────────

  Future<CustomFont?> importCustomFonts(List<File> files) async {
    final font = await _fontService.importFiles(files);
    if (font == null) return null;
    final catalog = [...state.customFonts, font];
    state = state.copyWith(customFonts: catalog);
    return font;
  }

  Future<void> deleteCustomFont(String id) async {
    await _fontService.deleteFont(id);
    final catalog = state.customFonts.where((f) => f.id != id).toList();
    final clearUi = state.uiFontId == id;
    final clearReading = state.readingFontId == id;
    state = state.copyWith(
      customFonts: catalog,
      uiFontId: clearUi ? () => null : null,
      readingFontId: clearReading ? () => null : null,
    );
    final prefs = await SharedPreferences.getInstance();
    if (clearUi) {
      await prefs.remove(_keyUiFontId);
    }
    if (clearReading) {
      await prefs.remove(_keyReadingFontId);
    }
  }

  Future<void> setUiFontId(String? id) async {
    if (id != null) {
      await _fontService.ensureLoadedById(id, state.customFonts);
    }
    state = state.copyWith(uiFontId: () => id);
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_keyUiFontId);
    } else {
      await prefs.setString(_keyUiFontId, id);
    }
  }

  Future<void> setReadingFontId(String? id) async {
    if (id != null) {
      await _fontService.ensureLoadedById(id, state.customFonts);
    }
    state = state.copyWith(readingFontId: () => id);
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_keyReadingFontId);
    } else {
      await prefs.setString(_keyReadingFontId, id);
    }
  }

  // ── Mutators ───────────────────────────────────────────────────────

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode, sepiaMode: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
    await prefs.setBool(_keySepiaMode, false);
  }

  Future<void> setSepiaMode(bool value) async {
    state = state.copyWith(sepiaMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySepiaMode, value);
  }

  Future<void> setFontFamily(String family) async {
    state = state.copyWith(fontFamily: family);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, family);
  }

  Future<void> setGoogleFont(String? font) async {
    state = state.copyWith(googleFont: () => font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleFont, font ?? '');
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
  }

  Future<void> setLineHeight(double height) async {
    state = state.copyWith(lineHeight: height);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineHeight, height);
  }

  Future<void> setFollowSystemAccent(bool value) async {
    state = state.copyWith(
      followSystemAccent: value,
      customAccentHex: value ? () => null : null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFollowSystemAccent, value);
    if (value) {
      await prefs.remove(_keyCustomAccentHex);
    }
  }

  Future<void> setAccent(AccentPreset accent) async {
    state = state.copyWith(
      accent: accent,
      customAccentHex: () => null,
      followSystemAccent: false,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentIndex, accent.index);
    await prefs.remove(_keyCustomAccentHex);
    await prefs.setBool(_keyFollowSystemAccent, false);
  }

  Future<void> setCustomAccentHex(String? hex) async {
    String? resolved;
    if (hex != null && hex.trim().isNotEmpty) {
      final parsed = ThemeState.resolveHex(hex);
      if (parsed == null) return;
      resolved = hex.trim();
    }
    state = state.copyWith(
      customAccentHex: () => resolved,
      followSystemAccent: resolved != null ? false : state.followSystemAccent,
    );
    final prefs = await SharedPreferences.getInstance();
    if (resolved == null) {
      await prefs.remove(_keyCustomAccentHex);
    } else {
      await prefs.setString(_keyCustomAccentHex, resolved);
      await prefs.setBool(_keyFollowSystemAccent, false);
    }
  }

  Future<void> setReadingFont(ReadingFont font) async {
    state = state.copyWith(
      readingFont: font,
      readingFontId: () => null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReadingFont, font.index);
    await prefs.remove(_keyReadingFontId);
  }

  Future<void> setPageWidth(double width) async {
    state = state.copyWith(pageWidth: width);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPageWidth, width);
  }

  Future<void> setTextAlign(TextAlign align) async {
    state = state.copyWith(textAlign: align);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextAlign, align.index);
  }

  Future<void> setHyphenation(bool value) async {
    state = state.copyWith(hyphenation: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHyphenation, value);
  }

  Future<void> setReducedMotion(bool value) async {
    state = state.copyWith(reducedMotion: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReducedMotion, value);
  }

  Future<void> setDefaultHighlight(String key) async {
    state = state.copyWith(defaultHighlight: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultHighlight, key);
  }

  Future<void> setHandMode(HandMode mode) async {
    state = state.copyWith(handMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHandMode, mode.index);
  }

  Future<void> setOneHandMode(bool value) async {
    state = state.copyWith(oneHandMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOneHandMode, value);
  }

  Future<void> setBionicReading(bool value) async {
    state = state.copyWith(bionicReading: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBionicReading, value);
  }

  Future<void> setAmoledMode(bool value) async {
    state = state.copyWith(amoledMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAmoledMode, value);
  }

  Future<void> setShowNsfwExtensions(bool value) async {
    state = state.copyWith(showNsfwExtensions: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowNsfwExtensions, value);
  }

  Future<void> setShowObsoleteExtensions(bool value) async {
    state = state.copyWith(showObsoleteExtensions: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowObsoleteExtensions, value);
  }

  Future<void> setImmersiveAutoHide(bool value) async {
    state = state.copyWith(immersiveAutoHide: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyImmersiveAutoHide, value);
  }

  Future<void> setPageStyle(PageStyle value) async {
    state = state.copyWith(pageStyle: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPageStyle, value.index);
  }

  void toggleTheme() {
    setThemeMode(state.isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// The canonical Riverpod provider for theme state.
///
/// Read state: `ref.watch(themeProvider)` returns [ThemeState].
/// Mutate: `ref.read(themeProvider.notifier).setFontSize(18)`.
final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
