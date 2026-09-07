import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';

/// Kenji-style ebook bottom chrome: circular prev/next + chapter pill.
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

  /// Height of the bar above [MediaQuery.viewPadding.bottom].
  static const double bodyHeight = 72;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedSlide(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      offset: visible ? Offset.zero : const Offset(0, 1),
      child: IgnorePointer(
        ignoring: !visible,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _CircleNav(
                  icon: Icons.chevron_left,
                  enabled: canGoPrevious,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      onTap: onChapters,
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              totalChapters > 0
                                  ? 'Chapter ${currentIndex + 1} of $totalChapters'
                                  : 'Chapters',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (readingTimeRemaining != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                readingTimeRemaining!,
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _CircleNav(
                  icon: Icons.chevron_right,
                  enabled: canGoNext,
                  onTap: onNext,
                  filled: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleNav extends StatelessWidget {
  const _CircleNav({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = filled && enabled ? c.accent : const Color(0xFF1A1A1A);
    final fg = filled && enabled
        ? c.onAccent
        : (enabled ? c.textPrimary : c.textTertiary.withValues(alpha: 0.45));
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: fg, size: 26),
        ),
      ),
    );
  }
}
