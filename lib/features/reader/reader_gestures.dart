import 'package:flutter/material.dart';

enum TapZoneLayout { leftRight, leftMiddleRight }

enum GestureOutcome {
  none,
  tapLeft,
  tapCenter,
  tapRight,
  doubleTap,
  longPress,
  swipeLeft,
  swipeRight,
  swipeUp,
  swipeDown,
}

class ReaderGestureConfig {
  final double edgeTapWidth;
  final double centerTapWidth;
  final double swipeVelocityThreshold;
  final double longPressTimeout;
  final double doubleTapTimeout;
  final bool lockVerticalSwipe;
  final bool lockHorizontalSwipe;

  const ReaderGestureConfig({
    this.edgeTapWidth = 0.3,
    this.centerTapWidth = 0.4,
    this.swipeVelocityThreshold = 600.0,
    this.longPressTimeout = 500.0,
    this.doubleTapTimeout = 300.0,
    this.lockVerticalSwipe = false,
    this.lockHorizontalSwipe = false,
  });
}

class ReaderGestureRecognizer {
  final ReaderGestureConfig config;
  final TapZoneLayout layout;

  ReaderGestureRecognizer({
    this.config = const ReaderGestureConfig(),
    this.layout = TapZoneLayout.leftRight,
  });

  GestureOutcome resolveTap(Offset local, Size size) {
    final third = size.width / 3;

    // L/M/R (mangayomi default): top strip = prev, bottom = next,
    // middle row = L | UI | R.
    if (layout == TapZoneLayout.leftMiddleRight) {
      final topBand = size.height * 2 / 9;
      final bottomBand = size.height * 7 / 9;
      if (local.dy < topBand) return GestureOutcome.tapLeft;
      if (local.dy > bottomBand) return GestureOutcome.tapRight;
    }

    // Shared L | M | R columns (also the entire L/R layout).
    if (local.dx < third) return GestureOutcome.tapLeft;
    if (local.dx > size.width - third) return GestureOutcome.tapRight;
    return GestureOutcome.tapCenter;
  }

  GestureOutcome resolveFling(double velocityPx, bool horizontal) {
    final v = velocityPx;
    if (horizontal && config.lockHorizontalSwipe) return GestureOutcome.none;
    if (!horizontal && config.lockVerticalSwipe) return GestureOutcome.none;

    final threshold = config.swipeVelocityThreshold;
    if (horizontal) {
      if (v > threshold) return GestureOutcome.swipeLeft;
      if (v < -threshold) return GestureOutcome.swipeRight;
    } else {
      if (v > threshold) return GestureOutcome.swipeUp;
      if (v < -threshold) return GestureOutcome.swipeDown;
    }
    return GestureOutcome.none;
  }

  bool isInEdgeZone(Offset local, Size size, bool left) {
    final w = size.width * config.edgeTapWidth;
    return left ? local.dx < w : local.dx > size.width - w;
  }

  bool isInCenterZone(Offset local, Size size) {
    final third = size.width * config.centerTapWidth;
    final centerStart = (size.width - third) / 2;
    return local.dx >= centerStart && local.dx <= centerStart + third;
  }

  GestureOutcome resolvePan(DragUpdateDetails details, Size size) {
    final dx = details.delta.dx;
    if (dx.abs() > details.delta.dy.abs()) {
      if (dx > 0) return GestureOutcome.swipeRight;
      return GestureOutcome.swipeLeft;
    }
    if (details.delta.dy > 0) return GestureOutcome.swipeDown;
    return GestureOutcome.swipeUp;
  }
}
