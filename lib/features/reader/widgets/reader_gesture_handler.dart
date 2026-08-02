import 'package:flutter/material.dart';
import '../reader_gestures.dart';

typedef ReaderGestureCallback = void Function();
typedef ReaderSwipeCallback = void Function(double velocity);

class ReaderGestureHandler extends StatelessWidget {
  final Widget child;
  final ReaderGestureCallback? onTap;
  final ReaderGestureCallback? onDoubleTap;
  final ReaderGestureCallback? onLongPress;
  final ReaderSwipeCallback? onHorizontalSwipe;
  final ReaderSwipeCallback? onVerticalSwipe;
  final double swipeThreshold;
  final ReaderGestureConfig gestureConfig;
  final TapZoneLayout tapLayout;

  const ReaderGestureHandler({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onHorizontalSwipe,
    this.onVerticalSwipe,
    this.swipeThreshold = 50.0,
    this.gestureConfig = const ReaderGestureConfig(),
    this.tapLayout = TapZoneLayout.leftRight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onHorizontalDragEnd: onHorizontalSwipe != null
          ? (details) {
              final v = details.velocity.pixelsPerSecond.dx;
              if (v.abs() > gestureConfig.swipeVelocityThreshold) {
                onHorizontalSwipe!(v);
              }
            }
          : null,
      onVerticalDragEnd: onVerticalSwipe != null
          ? (details) {
              final v = details.velocity.pixelsPerSecond.dy;
              if (v.abs() > gestureConfig.swipeVelocityThreshold) {
                onVerticalSwipe!(v);
              }
            }
          : null,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
