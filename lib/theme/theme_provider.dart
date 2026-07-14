import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_type.dart';

/// Persistent theme + typography preferences for the reader.
class ThemeProvider extends ChangeNotifier {
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
  static const _keyOneHandMode = 'one_hand_mode';
  static const _keyDefaultHighlight = 'default_highlight';
  static const _keyHandMode = 'hand_mode';
  static const _keyBionicReading = 'bionic_reading';

  ThemeMode _themeMode = ThemeMode.system;
  bool _sepiaMode = false;
  String _fontFamily = AppType.uiFont;
  String? _googleFont;
  double _fontSize = 17.0;
  double _lineHeight = 1.65;
  AccentPreset _accent = AccentPreset.indigo;
  String? _customAccentHex; // when set, overrides _accent
  ReadingFont _readingFont = ReadingFont.literata;
  double _pageWidth = 680;
  TextAlign _textAlign = TextAlign.left;
  bool _hyphenation = true;
  bool _reducedMotion = false;
  String _defaultHighlight = 'yellow';
  HandMode _handMode = HandMode.right;
  bool _oneHandMode = false;
  bool _bionicReading = false;

  ThemeMode get themeMode => _themeMode;
  bool get sepiaMode => _sepiaMode;
  String get fontFamily => _fontFamily;
  String? get googleFont => _googleFont;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  AccentPreset get accent => _accent;
  String? get customAccentHex => _customAccentHex;
  ReadingFont get readingFont => _readingFont;
  double get pageWidth => _pageWidth;
  TextAlign get textAlign => _textAlign;
  bool get hyphenation => _hyphenation;
  bool get reducedMotion => _reducedMotion;
  String get defaultHighlight => _defaultHighlight;
  HandMode get handMode => _handMode;
  bool get oneHandMode => _oneHandMode;
  bool get bionicReading => _bionicReading;

  /// The accent color the live theme should use.
  Color get accentColor {
    if (_customAccentHex != null && _customAccentHex!.isNotEmpty) {
      return _resolveHex(_customAccentHex!) ?? _presetAccent(_accent);
    }
    return _presetAccent(_accent);
  }

  Color _presetAccent(AccentPreset preset) {
    if (_sepiaMode) return AppColors.sepiaAccent;
    final isDark = isDarkMode;
    switch (preset) {
      case AccentPreset.indigo:
        return isDark ? AppColors.accentIndigoDark : AppColors.accentIndigo;
      case AccentPreset.amber:
        return isDark ? AppColors.accentAmberDark : AppColors.accentAmber;
      case AccentPreset.forest:
        return isDark ? AppColors.accentForestDark : AppColors.accentForest;
    }
  }

  static Color? _resolveHex(String hex) {
    var v = hex.trim();
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final i = int.tryParse(v, radix: 16);
    if (i == null) return null;
    return Color(i);
  }

  /// Current page background color, matching the active theme/sepia state.
  Color get bgColor {
    if (_sepiaMode) return AppColors.sepiaBg;
    return isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  }

  /// The Google Fonts family for the reader body, or null to use the
  /// system serif.
  String? get readingFontFamily => _readingFont.googleFontFamily;

  /// The font weight applied to the bolded prefix of each word in
  /// bionic-reading mode.
  FontWeight get bionicBoldWeight => FontWeight.w700;

  /// Fraction of each word (counted from the start) that gets bolded
  /// in bionic-reading mode.
  double get bionicBoldFraction => 0.4;

  bool get isDarkMode => _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  bool get isDark => isDarkMode;
  bool get isSepia => _sepiaMode;

  /// Live light theme.  Rebuilds the ThemeData with the user's
  /// selected accent so the whole app picks up accent changes.
  ThemeData get lightTheme => AppTheme.lightTheme(accent: accentColor);

  ThemeData get darkTheme => AppTheme.darkTheme(accent: accentColor);

  ThemeData get sepiaTheme => AppTheme.sepiaTheme(accent: accentColor);

  ThemeData get currentTheme {
    if (_sepiaMode) return sepiaTheme;
    return isDark ? darkTheme : lightTheme;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt(_keyThemeMode) ?? 0];
    _sepiaMode = prefs.getBool(_keySepiaMode) ?? false;
    _fontFamily = prefs.getString(_keyFontFamily) ?? AppType.uiFont;
    final fontStr = prefs.getString(_keyGoogleFont);
    _googleFont = fontStr?.isNotEmpty == true ? fontStr : null;
    _fontSize = prefs.getDouble(_keyFontSize) ?? 17.0;
    _lineHeight = prefs.getDouble(_keyLineHeight) ?? 1.65;
    _accent = AccentPreset.values[prefs.getInt(_keyAccentIndex) ?? 0];
    _customAccentHex = prefs.getString(_keyCustomAccentHex);
    _readingFont = ReadingFont.values[prefs.getInt(_keyReadingFont) ?? 1];
    _pageWidth = prefs.getDouble(_keyPageWidth) ?? 680;
    _textAlign = TextAlign.values[prefs.getInt(_keyTextAlign) ?? 0];
    _hyphenation = prefs.getBool(_keyHyphenation) ?? true;
    _reducedMotion = prefs.getBool(_keyReducedMotion) ?? false;
    _defaultHighlight = prefs.getString(_keyDefaultHighlight) ?? 'yellow';
    _handMode = HandMode.values[prefs.getInt(_keyHandMode) ?? 1];
    _oneHandMode = prefs.getBool(_keyOneHandMode) ?? false;
    _bionicReading = prefs.getBool(_keyBionicReading) ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _sepiaMode = false;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
    await prefs.setBool(_keySepiaMode, false);
  }

  Future<void> setSepiaMode(bool value) async {
    _sepiaMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySepiaMode, value);
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, family);
  }

  Future<void> setGoogleFont(String? font) async {
    _googleFont = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleFont, font ?? '');
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
  }

  Future<void> setLineHeight(double height) async {
    _lineHeight = height;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineHeight, height);
  }

  Future<void> setAccent(AccentPreset accent) async {
    _accent = accent;
    _customAccentHex = null; // switching to a preset clears custom
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentIndex, accent.index);
    await prefs.remove(_keyCustomAccentHex);
  }

  Future<void> setCustomAccentHex(String? hex) async {
    if (hex == null || hex.trim().isEmpty) {
      _customAccentHex = null;
    } else {
      final parsed = _resolveHex(hex);
      if (parsed == null) return; // ignore invalid input
      _customAccentHex = hex.trim();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_customAccentHex == null) {
      await prefs.remove(_keyCustomAccentHex);
    } else {
      await prefs.setString(_keyCustomAccentHex, _customAccentHex!);
    }
  }

  Future<void> setReadingFont(ReadingFont font) async {
    _readingFont = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReadingFont, font.index);
  }

  Future<void> setPageWidth(double width) async {
    _pageWidth = width;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPageWidth, width);
  }

  Future<void> setTextAlign(TextAlign align) async {
    _textAlign = align;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextAlign, align.index);
  }

  Future<void> setHyphenation(bool value) async {
    _hyphenation = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHyphenation, value);
  }

  Future<void> setReducedMotion(bool value) async {
    _reducedMotion = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReducedMotion, value);
  }

  Future<void> setDefaultHighlight(String key) async {
    _defaultHighlight = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultHighlight, key);
  }

  Future<void> setHandMode(HandMode mode) async {
    _handMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHandMode, mode.index);
  }

  Future<void> setOneHandMode(bool value) async {
    _oneHandMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOneHandMode, value);
  }

  Future<void> setBionicReading(bool value) async {
    _bionicReading = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBionicReading, value);
  }

  void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

enum HandMode { left, right }

enum AccentPreset { indigo, amber, forest }

/// Reading fonts the user can choose from.  Each entry knows the
/// Google Fonts family to use and a label for the UI.
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
