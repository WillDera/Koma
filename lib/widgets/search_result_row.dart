import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'progress_ring.dart';

enum SearchResultRowVariant { book, chapter, snippet }

class SearchResultRow extends StatelessWidget {
  final SearchResultRowVariant variant;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final IconData icon;
  final VoidCallback onTap;
  final double? progress;

  const SearchResultRow({
    super.key,
    required this.variant,
    required this.title,
    this.subtitle,
    this.trailingText,
    required this.icon,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brLg,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accentMuted,
                borderRadius: AppSpacing.brSm,
              ),
              child: Icon(icon, color: c.accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingText!,
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(width: 8),
              ProgressRing(progress: progress!, size: 32, strokeWidth: 2.5),
            ],
          ],
        ),
      ),
    );
  }
}
