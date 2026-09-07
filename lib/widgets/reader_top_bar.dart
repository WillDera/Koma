import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import 'icon_button_round.dart';

/// Kenji-style opaque top bar for the ebook reader.
class ReaderTopBar extends StatelessWidget {
  final String bookTitle;
  final String? bookAuthor;
  final String? chapterTitle;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onTtsToggle;
  final bool isTtsActive;
  final bool visible;
  final Color? background;

  const ReaderTopBar({
    super.key,
    required this.bookTitle,
    this.bookAuthor,
    required this.chapterTitle,
    required this.progress,
    required this.onBack,
    required this.onSettings,
    this.onTtsToggle,
    this.isTtsActive = false,
    required this.visible,
    this.background,
  });

  /// Height of the bar below [MediaQuery.viewPadding.top].
  static const double bodyHeight = 56;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = background ?? const Color(0xFF0F0F0F);
    final chapter = chapterTitle?.trim();
    return AnimatedSlide(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      offset: visible ? Offset.zero : const Offset(0, -1),
      child: IgnorePointer(
        ignoring: !visible,
        child: Material(
          color: bg,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButtonRound(
                        icon: Icons.arrow_back_ios_new,
                        size: 40,
                        variant: IconButtonVariant.tonal,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (chapter != null && chapter.isNotEmpty)
                              Text(
                                chapter,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onTtsToggle != null) ...[
                        const SizedBox(width: 4),
                        IconButtonRound(
                          icon: isTtsActive
                              ? Icons.headphones
                              : Icons.headphones_outlined,
                          size: 40,
                          variant: isTtsActive
                              ? IconButtonVariant.filled
                              : IconButtonVariant.tonal,
                          iconColor: isTtsActive ? c.onAccent : null,
                          backgroundColor: isTtsActive ? c.accent : null,
                          onPressed: onTtsToggle,
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButtonRound(
                        icon: Icons.settings_outlined,
                        size: 40,
                        variant: IconButtonVariant.tonal,
                        onPressed: onSettings,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                SizedBox(
                  height: 2,
                  child: Stack(
                    children: [
                      Container(color: c.border.withValues(alpha: 0.4)),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(color: c.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
