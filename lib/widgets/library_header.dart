import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'icon_button_round.dart';

/// A page header used by the main tabs and settings sub-screens.
/// Compact Kenji style: large title + muted subtitle, optional trailing actions.
class LibraryHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBack;
  final EdgeInsets padding;
  final double? titleFontSize;
  final FontWeight? titleFontWeight;

  const LibraryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showBackButton = false,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 16, 12),
    this.titleFontSize,
    this.titleFontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Compact 18px title + px-4 py-3 when back is shown.
    final effectivePadding = showBackButton &&
            padding == const EdgeInsets.fromLTRB(20, 8, 16, 12)
        ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
        : padding;
    final titleSize = titleFontSize ?? (showBackButton ? 18.0 : 24.0);
    final weight = titleFontWeight ?? FontWeight.w700;
    return Padding(
      padding: effectivePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) ...[
            IconButtonRound(
              icon: Icons.arrow_back_ios_new,
              size: 38,
              variant: IconButtonVariant.tonal,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 8),
          ] else if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
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
                    fontSize: titleSize,
                    fontWeight: weight,
                    letterSpacing: showBackButton ? 0 : -0.6,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...actions,
          ],
        ],
      ),
    );
  }
}
