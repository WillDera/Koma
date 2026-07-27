import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A color filter overlay for manga pages.
///
/// Wraps [ColorFiltered] with a [ColorMatrix] and exposes sliders for
/// brightness, contrast, saturation, and a tint color with opacity.
class ColorFilterWidget extends StatelessWidget {
  final double brightness;
  final double contrast;
  final double saturation;
  final Color? tint;
  final double tintOpacity;
  final Widget child;

  const ColorFilterWidget({
    super.key,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    this.tint,
    this.tintOpacity = 0.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final matrix = _buildColorMatrix();
    final filter = ColorFilter.matrix(matrix);
    final tintFilter = tint != null && tintOpacity > 0
        ? ColorFilter.mode(
            tint!.withValues(alpha: tintOpacity),
            BlendMode.srcOver,
          )
        : null;

    return ColorFiltered(
      colorFilter: filter,
      child: tintFilter != null
          ? ColorFiltered(colorFilter: tintFilter, child: child)
          : child,
    );
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
      rr,     rg,     rb,     0, brightnessOffset,
      gr,     gg,     gb,     0, brightnessOffset,
      br,     bg,     bb,     0, brightnessOffset,
      0,      0,      0,      1, 0,
    ]);
  }
}
