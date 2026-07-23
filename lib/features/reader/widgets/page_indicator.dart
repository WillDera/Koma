import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Page indicator showing "current / total" at bottom center.
///
/// Visible when UI is hidden and showPageNumbers is enabled.
/// Uses drop-shadow text for readability on any image background,
/// inspired by mangayomi's PageIndicator.
class PageIndicator extends StatelessWidget {
  final ValueListenable<int> pageListenable;
  final int totalPages;
  final bool isVisible;
  final bool showPageNumbers;

  const PageIndicator({
    super.key,
    required this.pageListenable,
    required this.totalPages,
    required this.isVisible,
    required this.showPageNumbers,
  });

  @override
  Widget build(BuildContext context) {
    if (isVisible || !showPageNumbers) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<int>(
        valueListenable: pageListenable,
        builder: (_, page, __) {
          return Text(
            '${page + 1} / $totalPages',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(offset: Offset(-1, -1), blurRadius: 2),
                Shadow(offset: Offset(1, -1), blurRadius: 2),
                Shadow(offset: Offset(1, 1), blurRadius: 2),
                Shadow(offset: Offset(-1, 1), blurRadius: 2),
              ],
            ),
          );
        },
      ),
    );
  }
}
