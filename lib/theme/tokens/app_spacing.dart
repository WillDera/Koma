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
  static const EdgeInsets pageHorizontalLg = EdgeInsets.symmetric(
    horizontal: xl,
  );
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
  static const BorderRadius brPill = BorderRadius.all(
    Radius.circular(radiusPill),
  );

  // ─── Elevation / shadows ───────────────────────────────────────────────
  static List<BoxShadow> shadow1({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark ? const Color(0x33000000) : const Color(0x0A000000),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> shadow2({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark ? const Color(0x40000000) : const Color(0x0F000000),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: isDark ? const Color(0x1A000000) : const Color(0x08000000),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> shadow3({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark ? const Color(0x55000000) : const Color(0x14000000),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: isDark ? const Color(0x28000000) : const Color(0x0A000000),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> shadow4({required bool isDark}) {
    return [
      BoxShadow(
        color: isDark ? const Color(0x66000000) : const Color(0x1F000000),
        blurRadius: 60,
        offset: const Offset(0, 24),
      ),
      BoxShadow(
        color: isDark ? const Color(0x33000000) : const Color(0x0A000000),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Subtle inset highlight at the top of light cards (paper feel).
  static Border? topHairline({required Color color}) {
    return Border(top: BorderSide(color: color, width: 0.5));
  }

  // ─── Aethelgard-specific tokens ────────────────────────────────────────

  /// Book cover aspect ratio — Aethelgard spec mandates 2:3 for all artwork
  /// cards. (Previous value was 3:4.)
  static const double coverAspectRatio = 2 / 3;

  /// Tactile scale-down on active touch for artwork cards (Aethelgard spec).
  static const double artworkScaleDown = 0.96;

  /// FAB glow — the only element in the Aethelgard system that uses a
  /// physical shadow. Simulates a light source emitting from the primary
  /// color: `0 0 20px rgba(accent, 0.3)`.
  static List<BoxShadow> fabGlow({required Color accent}) {
    return [
      BoxShadow(
        color: accent.withValues(alpha: 0.3),
        blurRadius: 20,
        spreadRadius: 0,
        offset: Offset.zero,
      ),
    ];
  }

  /// Glass surface decoration — 5% white fill + hairline border, matching
  /// the Aethelgard glass-surface / glass-border tokens. Apply inside a
  /// ClipRRect with BackdropFilter for the full glass effect.
  static BoxDecoration glassSurface({
    required Color surface,
    required Color border,
    BorderRadius? borderRadius,
    bool isDark = true,
  }) {
    final radius = borderRadius ?? brXl;
    return BoxDecoration(
      color: isDark
          ? const Color(0x0DFFFFFF) // 5% white
          : surface.withValues(alpha: 0.7),
      borderRadius: radius,
      border: Border.all(
        color: isDark
            ? const Color(0x14FFFFFF) // 8% white
            : border.withValues(alpha: 0.5),
        width: 0.5,
      ),
    );
  }
}
