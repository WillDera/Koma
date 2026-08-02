import 'package:flutter/material.dart';

enum TapZoneLayout { leftRight, leftTopRightBottom, leftCenterRight }

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
    final left = local.dx < third;
    final right = local.dx > size.width - third;

    if (layout == TapZoneLayout.leftTopRightBottom) {
      final top = local.dy < size.height / 2;
      if (left && top) return GestureOutcome.tapLeft;
      if (right && !top) return GestureOutcome.tapRight;
      return GestureOutcome.tapCenter;
    }
    if (layout == TapZoneLayout.leftCenterRight) {
      final centerH = size.height * 0.4;
      final centerY = local.dy.between(
        size.height / 2 - centerH,
        size.height / 2 + centerH,
      );
      if (!centerY) return GestureOutcome.none;
      if (left) return GestureOutcome.tapLeft;
      if (right) return GestureOutcome.tapRight;
      return GestureOutcome.tapCenter;
    }

    if (left) return GestureOutcome.tapLeft;
    if (right) return GestureOutcome.tapRight;
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

extension DoubleExtension on double {
  bool between(double min, double max) => this >= min && this <= max;
}
