import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// StashReader typography.
///
/// UI: Inter. Reading: Literata. Mono: JetBrains Mono.
/// All three come from google_fonts (offline-cached after first use).
class AppType {
  AppType._();

  static const String _ui = 'Inter';
  static const String _reading = 'Literata';
  static const String _mono = 'JetBrainsMono';

  /// UI TextTheme — used for everything except the reader body.
  static TextTheme ui() {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 26,
        height: 32 / 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 22 / 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 20 / 13,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }

  /// Reading body — used in ReaderScreen for chapter content.
  /// Returns a TextStyle (not a TextTheme) because the reader uses a
  /// single TextStyle pipeline (SelectableText.rich).
  static TextStyle reading({
    double fontSize = 17,
    double lineHeight = 1.65,
    Color? color,
  }) {
    return GoogleFonts.literata(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.05,
    );
  }

  /// Reading body for a specific font family (from ThemeProvider.readingFont).
  /// Returns the system default font if [fontFamily] is null.
  static TextStyle fontStyle({
    String? fontFamily,
    double fontSize = 17,
    double lineHeight = 1.65,
    Color? color,
  }) {
    if (fontFamily == null) {
      return TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: color,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.05,
      );
    }
    // Use GoogleFonts.getFont which loads & caches any supported font.
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.05,
    );
  }

  /// Monospaced — metadata, dates, file paths.
  static TextStyle mono({double fontSize = 12, Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      height: 1.4,
      color: color,
      fontWeight: FontWeight.w400,
    );
  }

  /// Italic reading style (for chapter titles, quotes, snippet text).
  static TextStyle readingItalic({
    double fontSize = 17,
    double lineHeight = 1.65,
    Color? color,
  }) {
    return GoogleFonts.literata(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
    );
  }

  /// Author display name (used on book covers, library cards).
  static const String uiFont = _ui;
  static const String readingFont = _reading;
  static const String monoFont = _mono;
}
