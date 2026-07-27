import 'package:flutter/material.dart';

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

  const ReaderGestureHandler({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onHorizontalSwipe,
    this.onVerticalSwipe,
    this.swipeThreshold = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onHorizontalDragEnd: onHorizontalSwipe != null
          ? (details) {
              final velocity = details.velocity.pixelsPerSecond.dx;
              if (velocity.abs() > swipeThreshold * 10) {
                onHorizontalSwipe!(velocity);
              }
            }
          : null,
      onVerticalDragEnd: onVerticalSwipe != null
          ? (details) {
              final velocity = details.velocity.pixelsPerSecond.dy;
              if (velocity.abs() > swipeThreshold * 10) {
                onVerticalSwipe!(velocity);
              }
            }
          : null,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
