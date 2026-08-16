import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/glass_blur.dart';
import 'icon_button_round.dart';

class ReaderBottomBar extends StatelessWidget {
  final VoidCallback onChapters;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;
  final bool canGoPrevious;
  final bool visible;
  final int currentIndex;
  final int totalChapters;
  final String? readingTimeRemaining;
  final Color? background;

  const ReaderBottomBar({
    super.key,
    required this.onChapters,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
    required this.canGoPrevious,
    required this.visible,
    required this.currentIndex,
    required this.totalChapters,
    this.readingTimeRemaining,
    this.background,
  });

  /// Height of the bar above [MediaQuery.viewPadding.bottom] (padding + buttons).
  /// Keep in sync with the Row below; page padding uses this.
  static const double bodyHeight = 56;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = background ?? c.bg;
    return AnimatedSlide(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      offset: visible ? Offset.zero : const Offset(0, 1),
      child: IgnorePointer(
        ignoring: !visible,
        child: GlassBlur.layer(
        child: Container(
            color: bg.withValues(alpha: 0.78),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    IconButtonRound(
                      icon: Icons.menu,
                      size: 40,
                      variant: IconButtonVariant.tonal,
                      onPressed: onChapters,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chapter ${currentIndex + 1} of $totalChapters',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (readingTimeRemaining != null)
                            Text(
                              readingTimeRemaining!,
                              style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButtonRound(
                      icon: Icons.chevron_left,
                      size: 40,
                      variant: IconButtonVariant.tonal,
                      onPressed: canGoPrevious ? onPrevious : null,
                    ),
                    const SizedBox(width: 8),
                    IconButtonRound(
                      icon: Icons.chevron_right,
                      size: 40,
                      variant: IconButtonVariant.filled,
                      iconColor: c.onAccent,
                      backgroundColor: c.accent,
                      onPressed: canGoNext ? onNext : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
