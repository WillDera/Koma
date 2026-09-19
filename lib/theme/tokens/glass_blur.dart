import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared glass-blur helpers for nav and reader chrome.
///
/// Blur is isolated with [RepaintBoundary] so scrolling content underneath
/// doesn't dirty the blurred layer's paint every frame. Sigma stays modest
/// for cheaper sampling under Impeller.
abstract final class GlassBlur {
  static const double sigma = 8;

  static ImageFilter get filter =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  /// Clips + blurs [child], isolated from sibling repaints.
  static Widget layer({
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    final blurred = BackdropFilter(filter: filter, child: child);
    final clipped = borderRadius != null
        ? ClipRRect(borderRadius: borderRadius, child: blurred)
        : ClipRect(child: blurred);
    return RepaintBoundary(child: clipped);
  }
}
