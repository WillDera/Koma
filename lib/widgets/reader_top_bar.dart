import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import 'icon_button_round.dart';

/// Auto-hiding top bar for the reader. Slides up/down with the parent.
class ReaderTopBar extends StatelessWidget {
  final String bookTitle;
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
    required this.chapterTitle,
    required this.progress,
    required this.onBack,
    required this.onSettings,
    this.onTtsToggle,
    this.isTtsActive = false,
    required this.visible,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = background ?? c.bg;
    return AnimatedSlide(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      offset: visible ? Offset.zero : const Offset(0, -1),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: bg.withValues(alpha: 0.78),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      children: [
                        IconButtonRound(
                          icon: Icons.arrow_back_ios_new,
                          size: 40,
                          variant: IconButtonVariant.tonal,
                          onPressed: onBack,
                        ),
                        const SizedBox(width: 4),
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
                              if (chapterTitle != null)
                                Text(
                                  chapterTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textSecondary,
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
                            iconColor: isTtsActive ? context.colors.onAccent : null,
                            backgroundColor:
                                isTtsActive ? context.colors.accent : null,
                            onPressed: onTtsToggle,
                          ),
                        ],
                        const SizedBox(width: 4),
                        IconButtonRound(
                          icon: Icons.tune,
                          size: 40,
                          variant: IconButtonVariant.tonal,
                          onPressed: onSettings,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  // Thin progress line at the very top
                  SizedBox(
                    height: 2,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(color: c.border),
                            FractionallySizedBox(
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(color: c.accent),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
