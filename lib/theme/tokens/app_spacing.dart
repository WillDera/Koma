import 'package:flutter/material.dart';

/// Koma spacing, radii, and elevation tokens.
class AppSpacing {
  AppSpacing._();

  // ─── Spacing scale (multiples of 4) ─────────────────────────────────────
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 40;
  static const double xxxxxl = 56;

  /// Convenience EdgeInsets for common padding presets.
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageHorizontalLg = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets cardMd = EdgeInsets.all(lg);
  static const EdgeInsets cardLg = EdgeInsets.all(xl);
  static const EdgeInsets sheetLg = EdgeInsets.fromLTRB(xl, lg, xl, xxl);

  // ─── Border radii ───────────────────────────────────────────────────────
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusXxl = 32;
  static const double radiusPill = 999;

  static const Radius rXs = Radius.circular(radiusXs);
  static const Radius rSm = Radius.circular(radiusSm);
  static const Radius rMd = Radius.circular(radiusMd);
  static const Radius rLg = Radius.circular(radiusLg);
  static const Radius rXl = Radius.circular(radiusXl);

  static BorderRadius brXs = BorderRadius.circular(radiusXs);
  static BorderRadius brSm = BorderRadius.circular(radiusSm);
  static BorderRadius brMd = BorderRadius.circular(radiusMd);
  static BorderRadius brLg = BorderRadius.circular(radiusLg);
  static BorderRadius brXl = BorderRadius.circular(radiusXl);
  static BorderRadius brXxl = BorderRadius.circular(radiusXxl);
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(radiusPill));

  // ─── Elevation / shadows ───────────────────────────────────────────────
  static List<BoxShadow> shadow1({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark
            ? const Color(0x33000000)
            : const Color(0x0A000000),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> shadow2({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark
            ? const Color(0x40000000)
            : const Color(0x0F000000),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: isDark
            ? const Color(0x1A000000)
            : const Color(0x08000000),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> shadow3({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark
            ? const Color(0x55000000)
            : const Color(0x14000000),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: isDark
            ? const Color(0x28000000)
            : const Color(0x0A000000),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> shadow4({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark
            ? const Color(0x66000000)
            : const Color(0x1F000000),
        blurRadius: 60,
        offset: const Offset(0, 24),
      ),
      BoxShadow(
        color: isDark
            ? const Color(0x33000000)
            : const Color(0x0A000000),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Subtle inset highlight at the top of light cards (paper feel).
  static Border? topHairline({required Color color}) {
    return Border(
      top: BorderSide(color: color, width: 0.5),
    );
  }
}
