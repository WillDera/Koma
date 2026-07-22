import 'package:flutter/animation.dart';

/// Koma motion tokens — durations, curves, and a few common helpers.
class AppMotion {
  AppMotion._();

  // ─── Durations ──────────────────────────────────────────────────────────
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 360);

  // ─── Curves ─────────────────────────────────────────────────────────────
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.0, 0.0, 0.2, 1.0);
  static const Curve accelerate = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);

  // Spring spec for the pill nav active indicator & FAB press.
  static const SpringDescription spring = SpringDescription(
    damping: 18,
    stiffness: 220,
    mass: 1,
  );

  // Soft spring (gentle bounce) used for press feedback.
  static const SpringDescription springSoft = SpringDescription(
    damping: 22,
    stiffness: 280,
    mass: 0.9,
  );
}
