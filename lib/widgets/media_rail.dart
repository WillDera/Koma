import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// Horizontal media rail with a title row and optional "View all" action.
///
/// Used by Library (Continue / Books / Manga / Collections) and Explore idle.
class MediaRail extends StatelessWidget {
  const MediaRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.subtitle,
    this.onViewAll,
    this.viewAllLabel = 'View all',
    this.height = 200,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 4),
    this.separatorWidth = 12,
  });

  final String title;
  final String? subtitle;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onViewAll;
  final String viewAllLabel;
  final double height;
  final EdgeInsetsGeometry padding;
  final double separatorWidth;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();
    final c = context.colors;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onViewAll != null)
                AnimatedPress(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        viewAllLabel,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(width: separatorWidth),
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact cover tile used inside [MediaRail]s (fixed width).
class MediaRailCover extends StatelessWidget {
  const MediaRailCover({
    super.key,
    required this.child,
    this.width = 118,
  });

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

/// Section header used when Library is in "View all" grid mode.
class MediaRailViewAllBar extends StatelessWidget {
  const MediaRailViewAllBar({
    super.key,
    required this.title,
    required this.onBack,
    this.countLabel,
  });

  final String title;
  final String? countLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                if (countLabel != null)
                  Text(
                    countLabel!,
                    style: TextStyle(color: c.textTertiary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft divider between rails.
class MediaRailGap extends StatelessWidget {
  const MediaRailGap({super.key, this.height = 8});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Empty placeholder matching rail chrome when a section has no items yet.
class MediaRailEmptyHint extends StatelessWidget {
  const MediaRailEmptyHint({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: AppSpacing.brLg,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Text(
          message,
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}
