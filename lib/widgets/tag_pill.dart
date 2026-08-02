import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

enum TagPillVariant { filter, static_, removable }

/// A small pill used for tags, filters, and similar inline labels.
class TagPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Color? color;
  final TagPillVariant variant;
  final IconData? leadingIcon;

  const TagPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.color,
    this.variant = TagPillVariant.static_,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = color ?? c.accent;
    final bg = selected ? accent.withValues(alpha: 0.14) : c.surfaceMuted;
    final fg = selected ? accent : c.textSecondary;
    final borderColor = selected
        ? accent.withValues(alpha: 0.35)
        : Colors.transparent;

    final child = AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.brPill,
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 12, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.1,
              height: 1.1,
            ),
          ),
          if (onRemove != null && variant == TagPillVariant.removable) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close, size: 12, color: fg),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.95,
      duration: AppMotion.fast,
      child: child,
    );
  }
}
