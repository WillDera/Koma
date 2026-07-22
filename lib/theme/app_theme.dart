import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_type.dart';

/// Koma theme — built from design tokens (colors, type, spacing).
///
/// Three modes: Light (warm paper), Dark (cool charcoal), Sepia (paper-like).
/// Single sophisticated indigo anchor (`AppColors.accentIndigo`).
class AppTheme {
  AppTheme._();

  // ─── Accent ─────────────────────────────────────────────────────────────
  static const Color accent = AppColors.lightAccent;
  static const Color accentDark = AppColors.darkAccent;
  static const Color accentSepia = AppColors.sepiaAccent;

  // Backwards-compat aliases (kept so existing call-sites still compile
  // during the rewrite). New code should use `AppColors.*` directly.
  static const Color accentLight = AppColors.accentAmber;
  static const Color lightBackground = AppColors.lightBg;
  static const Color lightSurface = AppColors.lightSurface;
  static const Color lightText = AppColors.lightTextPrimary;
  static const Color lightTextSecondary = AppColors.lightTextSecondary;
  static const Color lightBorder = AppColors.lightBorder;
  static const Color darkBackground = AppColors.darkBg;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkText = AppColors.darkTextPrimary;
  static const Color darkTextSecondary = AppColors.darkTextSecondary;
  static const Color darkBorder = AppColors.darkBorder;
  static const Color sepiaBackground = AppColors.sepiaBg;
  static const Color sepiaSurface = AppColors.sepiaSurface;
  static const Color sepiaText = AppColors.sepiaTextPrimary;
  static const Color sepiaTextSecondary = AppColors.sepiaTextSecondary;
  static const Color sepiaBorder = AppColors.sepiaBorder;
  static const Color sepiaAccent = AppColors.sepiaAccent;

  // ─── Public entry points ───────────────────────────────────────────────
  static ThemeData lightTheme({Color? accent}) {
    final a = accent ?? AppColors.lightAccent;
    return _buildTheme(
      brightness: Brightness.light,
      bg: AppColors.lightBg,
      bgElevated: AppColors.lightBgElevated,
      surface: AppColors.lightSurface,
      surfaceMuted: AppColors.lightSurfaceMuted,
      border: AppColors.lightBorder,
      borderStrong: AppColors.lightBorderStrong,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      textTertiary: AppColors.lightTextTertiary,
      accent: a,
      accentMuted: _muted(a, AppColors.lightSurface),
      onAccent: _onAccentFor(a),
    );
  }

  static ThemeData darkTheme({Color? accent}) {
    final a = accent ?? AppColors.darkAccent;
    return _buildTheme(
      brightness: Brightness.dark,
      bg: AppColors.darkBg,
      bgElevated: AppColors.darkBgElevated,
      surface: AppColors.darkSurface,
      surfaceMuted: AppColors.darkSurfaceMuted,
      border: AppColors.darkBorder,
      borderStrong: AppColors.darkBorderStrong,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textTertiary: AppColors.darkTextTertiary,
      accent: a,
      accentMuted: _muted(a, AppColors.darkSurface),
      onAccent: _onAccentFor(a),
    );
  }

  static ThemeData sepiaTheme({Color? accent}) {
    final a = accent ?? AppColors.sepiaAccent;
    return _buildTheme(
      brightness: Brightness.light,
      bg: AppColors.sepiaBg,
      bgElevated: AppColors.sepiaBgElevated,
      surface: AppColors.sepiaSurface,
      surfaceMuted: AppColors.sepiaSurfaceMuted,
      border: AppColors.sepiaBorder,
      borderStrong: AppColors.sepiaBorderStrong,
      textPrimary: AppColors.sepiaTextPrimary,
      textSecondary: AppColors.sepiaTextSecondary,
      textTertiary: AppColors.sepiaTextTertiary,
      accent: a,
      accentMuted: _muted(a, AppColors.sepiaSurface),
      onAccent: _onAccentFor(a),
    );
  }

  /// A soft tinted surface derived from the accent — used for
  /// selected states, chip backgrounds, and the active nav indicator.
  static Color _muted(Color accent, Color surface) {
    return Color.lerp(surface, accent, 0.14)!;
  }

  /// Text/icon color used ON TOP of the accent (e.g. inside the FAB
  /// or a primary button). White for dark accents, near-black for
  /// very light accents.
  static Color _onAccentFor(Color accent) {
    final luminance = accent.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF1A1815) : Colors.white;
  }

  // ─── Builder ───────────────────────────────────────────────────────────
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color bgElevated,
    required Color surface,
    required Color surfaceMuted,
    required Color border,
    required Color borderStrong,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color accent,
    required Color accentMuted,
    required Color onAccent,
  }) {
    final textTheme = AppType.ui().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      tertiary: accent,
      onTertiary: onAccent,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceMuted,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: textPrimary,
      onInverseSurface: bg,
      inversePrimary: accentMuted,
      surfaceTint: accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      fontFamily: AppType.uiFont,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: accent.withValues(alpha: 0.06),
      focusColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.08),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brLg,
          side: BorderSide(color: border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentMuted,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(color: textPrimary),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: textSecondary, size: 22),
        ),
        height: 64,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brLg,
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(color: onAccent),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0.5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: accentMuted,
        disabledColor: surfaceMuted,
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: accent),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        iconTheme: IconThemeData(color: textSecondary, size: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        hoverColor: surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyLarge?.copyWith(color: textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: accent),
        helperStyle: textTheme.bodySmall?.copyWith(color: textTertiary),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.danger),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.brSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.brSm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.brSm,
          borderSide: BorderSide(color: accent, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.brSm,
          borderSide: BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.brSm,
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: bg),
        actionTextColor: accent,
        disabledActionTextColor: textTertiary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brMd,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brXl,
          side: BorderSide(color: border, width: 0.5),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: textPrimary),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        alignment: Alignment.center,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: bgElevated,
        modalElevation: 0,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppSpacing.rXl),
        ),
        constraints: const BoxConstraints(maxWidth: 560),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: textPrimary),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: textSecondary),
        leadingAndTrailingTextStyle:
            textTheme.labelMedium?.copyWith(color: textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brMd,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
        valueIndicatorColor: textPrimary,
        valueIndicatorTextStyle:
            textTheme.labelSmall?.copyWith(color: bg),
        trackHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return borderStrong;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.35);
          }
          return surfaceMuted;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onAccent),
        side: BorderSide(color: borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return borderStrong;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
        circularTrackColor: border,
        linearMinHeight: 2,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary,
          borderRadius: AppSpacing.brSm,
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: bg),
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      primaryIconTheme: IconThemeData(color: textPrimary, size: 22),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.20),
        selectionHandleColor: accent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brMd,
          side: BorderSide(color: border, width: 0.5),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium?.copyWith(color: textPrimary),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(bgElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppSpacing.brMd,
              side: BorderSide(color: border, width: 0.5),
            ),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        KomaColors(
          bg: bg,
          bgElevated: bgElevated,
          surface: surface,
          surfaceMuted: surfaceMuted,
          border: border,
          borderStrong: borderStrong,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textTertiary: textTertiary,
          accent: accent,
          accentMuted: accentMuted,
          onAccent: onAccent,
        ),
      ],
    );
  }
}

/// Custom theme extension exposing our semantic color tokens directly
/// (no more `isDark ? X : Y` ladders in every widget).
@immutable
class KomaColors extends ThemeExtension<KomaColors> {
  final Color bg;
  final Color bgElevated;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentMuted;
  final Color onAccent;

  const KomaColors({
    required this.bg,
    required this.bgElevated,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentMuted,
    required this.onAccent,
  });

  @override
  KomaColors copyWith({
    Color? bg,
    Color? bgElevated,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentMuted,
    Color? onAccent,
  }) {
    return KomaColors(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  KomaColors lerp(ThemeExtension<KomaColors>? other, double t) {
    if (other is! KomaColors) return this;
    return KomaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Convenience accessor — `context.colors` returns the KomaColors
/// extension for the current theme. Falls back to light tokens if the
/// extension is missing (it never should be — we set it in app_theme).
extension KomaColorsAccess on BuildContext {
  KomaColors get colors {
    final ext = Theme.of(this).extension<KomaColors>();
    if (ext != null) return ext;
    return const KomaColors(
      bg: AppColors.lightBg,
      bgElevated: AppColors.lightBgElevated,
      surface: AppColors.lightSurface,
      surfaceMuted: AppColors.lightSurfaceMuted,
      border: AppColors.lightBorder,
      borderStrong: AppColors.lightBorderStrong,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      textTertiary: AppColors.lightTextTertiary,
      accent: AppColors.lightAccent,
      accentMuted: AppColors.lightAccentMuted,
      onAccent: AppColors.lightOnAccent,
    );
  }
}
