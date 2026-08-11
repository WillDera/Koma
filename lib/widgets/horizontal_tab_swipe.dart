import 'package:flutter/material.dart';

/// Horizontal fling over [child] switches tabs. Vertical scrolling still wins
/// the gesture arena for primarily-vertical drags.
class HorizontalTabSwipe extends StatelessWidget {
  final int tabIndex;
  final int tabCount;
  final ValueChanged<int> onTabChanged;
  final Widget child;

  /// Minimum |primaryVelocity| (px/s) to count as a tab fling.
  final double minVelocity;

  const HorizontalTabSwipe({
    super.key,
    required this.tabIndex,
    required this.tabCount,
    required this.onTabChanged,
    required this.child,
    this.minVelocity = 350,
  });

  @override
  Widget build(BuildContext context) {
    if (tabCount < 2) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity;
        if (v == null) return;
        if (v <= -minVelocity && tabIndex < tabCount - 1) {
          onTabChanged(tabIndex + 1);
        } else if (v >= minVelocity && tabIndex > 0) {
          onTabChanged(tabIndex - 1);
        }
      },
      child: child,
    );
  }
}
