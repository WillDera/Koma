import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A color filter overlay for manga pages.
///
/// Supports brightness / contrast / saturation, an optional wash tint,
/// and sepia paper multiply when the app theme is sepia.
class ColorFilterWidget extends StatelessWidget {
  final double brightness;
  final double contrast;
  final double saturation;
  final Color? tint;
  final double tintOpacity;
  /// When set, multiplies page pixels by this color so white paper becomes
  /// the tint (e.g. app sepia bg) while black ink stays dark.
  final Color? paperMultiply;
  final Widget child;

  const ColorFilterWidget({
    super.key,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    this.tint,
    this.tintOpacity = 0.0,
    this.paperMultiply,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasTint = tint != null && tintOpacity > 0;
    final hasPaper = paperMultiply != null;
    // Identity filter (default brightness/contrast/saturation, no tint) —
    // skip ColorFiltered so page tiles aren't forced through an extra layer.
    final isIdentity =
        brightness == 1.0 &&
        contrast == 1.0 &&
        saturation == 1.0 &&
        !hasTint &&
        !hasPaper;
    if (isIdentity) return child;

    Widget result = child;

    if (brightness != 1.0 || contrast != 1.0 || saturation != 1.0) {
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(_buildColorMatrix()),
        child: result,
      );
    }

    if (hasTint) {
      result = ColorFiltered(
        colorFilter: ColorFilter.mode(
          tint!.withValues(alpha: tintOpacity),
          BlendMode.srcOver,
        ),
        child: result,
      );
    }

    if (hasPaper) {
      result = ColorFiltered(
        colorFilter: ColorFilter.mode(paperMultiply!, BlendMode.multiply),
        child: result,
      );
    }

    return result;
  }

  Float64List _buildColorMatrix() {
    final b = brightness;
    final c = contrast;
    final s = saturation;

    final brightnessOffset = (b - 1.0) * 255.0;

    final rr = c * s;
    final rg = c * s * 0.0;
    final rb = c * s * 0.0;
    final gr = c * s * 0.0;
    final gg = c * s;
    final gb = c * s * 0.0;
    final br = c * s * 0.0;
    final bg = c * s * 0.0;
    final bb = c * s;

    return Float64List.fromList([
      rr,
      rg,
      rb,
      0,
      brightnessOffset,
      gr,
      gg,
      gb,
      0,
      brightnessOffset,
      br,
      bg,
      bb,
      0,
      brightnessOffset,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}
