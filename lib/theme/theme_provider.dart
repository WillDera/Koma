import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/system_font_service.dart';
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
  static const _keyThemeMode = 'theme_mode';
  static const _keySepiaMode = 'sepia_mode';
  static const _keyFontFamily = 'font_family';
  static const _keyGoogleFont = 'google_font';
  static const _keyFontSize = 'font_size';
  static const _keyLineHeight = 'line_height';
  static const _keyAccentIndex = 'accent_index';
  static const _keyCustomAccentHex = 'custom_accent_hex';
  static const _keyReadingFont = 'reading_font';
  static const _keyPageWidth = 'page_width';
  static const _keyTextAlign = 'text_align';
  static const _keyHyphenation = 'hyphenation';
  static const _keyReducedMotion = 'reduced_motion';
  static const _keyDefaultHighlight = 'default_highlight';
  static const _keyHandMode = 'hand_mode';
  static const _keyOneHandMode = 'one_hand_mode';
  static const _keyBionicReading = 'bionic_reading';
  static const _keyUseDeviceFont = 'use_device_font';
  static const _keyAmoledMode = 'amoled_mode';
  static const _keyShowNsfwExtensions = 'show_nsfw_extensions';
  static const _keyShowObsoleteExtensions = 'show_obsolete_extensions';
  static const _keyImmersiveAutoHide = 'immersive_auto_hide';
  static const _keyPageStyle = 'page_style';

  @override
  ThemeState build() {
    // Default state — init() is called from main.dart before first paint
    // to load persisted values.
    return const ThemeState();
  }

  /// Load persisted preferences from disk. Called once at startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    state = ThemeState(
      themeMode: ThemeMode.values[prefs.getInt(_keyThemeMode) ?? 0],
      sepiaMode: prefs.getBool(_keySepiaMode) ?? false,
      fontFamily: prefs.getString(_keyFontFamily) ?? state.fontFamily,
      googleFont: _nonEmpty(prefs.getString(_keyGoogleFont)),
      fontSize: prefs.getDouble(_keyFontSize) ?? 17.0,
      lineHeight: prefs.getDouble(_keyLineHeight) ?? 1.65,
      accent: AccentPreset.values[prefs.getInt(_keyAccentIndex) ?? 0],
      customAccentHex: prefs.getString(_keyCustomAccentHex),
      readingFont: ReadingFont.values[prefs.getInt(_keyReadingFont) ?? 1],
      pageWidth: prefs.getDouble(_keyPageWidth) ?? 680,
      textAlign: TextAlign.values[prefs.getInt(_keyTextAlign) ?? 0],
      hyphenation: prefs.getBool(_keyHyphenation) ?? true,
      reducedMotion: prefs.getBool(_keyReducedMotion) ?? false,
      defaultHighlight: prefs.getString(_keyDefaultHighlight) ?? 'yellow',
      handMode: HandMode.values[prefs.getInt(_keyHandMode) ?? 1],
      oneHandMode: prefs.getBool(_keyOneHandMode) ?? false,
      bionicReading: prefs.getBool(_keyBionicReading) ?? false,
      useDeviceFont: prefs.getBool(_keyUseDeviceFont) ?? false,
      amoledMode: prefs.getBool(_keyAmoledMode) ?? false,
      showNsfwExtensions: prefs.getBool(_keyShowNsfwExtensions) ?? false,
      showObsoleteExtensions: prefs.getBool(_keyShowObsoleteExtensions) ?? false,
      immersiveAutoHide: prefs.getBool(_keyImmersiveAutoHide) ?? false,
      pageStyle: PageStyle.values[
      (prefs.getInt(_keyPageStyle) ?? 0)
          .clamp(0, PageStyle.values.length - 1)],
    );
    if (state.useDeviceFont) {
      unawaited(_resolveSystemFont());
    }
  }

  static String? _nonEmpty(String? s) =>
      s != null && s.isNotEmpty ? s : null;

  Future<String?> _resolveSystemFont() async {
    if (state.systemFontFamily != null) return state.systemFontFamily;
    final font = await SystemFontService().getSystemTypeface();
    if (font != null) {
      state = state.copyWith(systemFontFamily: font);
    }
    return font;
  }

  // ── Theme convenience getters (forwarded from state) ───────────────

  /// Live light theme built from the current accent color.
  ThemeData get lightTheme => AppTheme.lightTheme(
    accent: state.accentColor,
    fontFamily: _fontFamilyForMode(),
  );
  ThemeData get darkTheme => AppTheme.darkTheme(
    accent: state.accentColor,
    amoled: state.amoledMode,
    fontFamily: _fontFamilyForMode(),
  );
  ThemeData get sepiaTheme => AppTheme.sepiaTheme(
    accent: state.accentColor,
    fontFamily: _fontFamilyForMode(),
  );

  String? _fontFamilyForMode() {
    if (!state.useDeviceFont) return AppType.uiFont;
    return state.systemFontFamily;
  }

  ThemeData get currentTheme {
    if (state.sepiaMode) return sepiaTheme;
    if (state.isDark) return darkTheme;
    return lightTheme;
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

  Future<void> setAccent(AccentPreset accent) async {
    state = state.copyWith(accent: accent, customAccentHex: () => null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentIndex, accent.index);
    await prefs.remove(_keyCustomAccentHex);
  }

  Future<void> setCustomAccentHex(String? hex) async {
    String? resolved;
    if (hex != null && hex.trim().isNotEmpty) {
      final parsed = ThemeState.resolveHex(hex);
      if (parsed == null) return;
      resolved = hex.trim();
    }
    state = state.copyWith(customAccentHex: () => resolved);
    final prefs = await SharedPreferences.getInstance();
    if (resolved == null) {
      await prefs.remove(_keyCustomAccentHex);
    } else {
      await prefs.setString(_keyCustomAccentHex, resolved);
    }
  }

  Future<void> setReadingFont(ReadingFont font) async {
    state = state.copyWith(readingFont: font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReadingFont, font.index);
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

  Future<void> setUseDeviceFont(bool value) async {
    state = state.copyWith(useDeviceFont: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDeviceFont, value);
    if (value) {
      unawaited(_resolveSystemFont());
    }
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
final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
