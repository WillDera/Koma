import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

enum IconButtonVariant { plain, filled, tonal }

/// A round icon button. 36 / 40 / 44 sizes. Three variants.
/// Accepts either an [AppIconData] (Hugeicon or Material) via [iconData]
/// or a plain [IconData] via [icon] for backward compatibility.
class IconButtonRound extends StatelessWidget {
  final IconData? icon;
  final AppIconData? iconData;
  final VoidCallback? onPressed;
  final double size;
  final IconButtonVariant variant;
  final String? tooltip;
  final Color? iconColor;
  final Color? backgroundColor;

  const IconButtonRound({
    super.key,
    this.icon,
    this.iconData,
    this.onPressed,
    this.size = 40,
    this.variant = IconButtonVariant.tonal,
    this.tooltip,
    this.iconColor,
    this.backgroundColor,
  }) : assert(
         icon != null || iconData != null,
         'Either icon or iconData must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = onPressed == null;

    final (bg, fg) = switch (variant) {
      IconButtonVariant.plain => (
        Colors.transparent,
        iconColor ?? c.textPrimary,
      ),
      IconButtonVariant.filled => (
        backgroundColor ?? c.iconWell,
        iconColor ?? c.textPrimary,
      ),
      // Figma header tile: rounded-xl icon well, muted icon (18px).
      IconButtonVariant.tonal => (
        backgroundColor ?? c.iconWell,
        iconColor ?? c.textSecondary,
      ),
    };

    final iconWidget = iconData != null
        ? AppIcon(data: iconData!, size: size * 0.46, color: fg)
        : Icon(icon, size: size * 0.48, color: fg);

    final btn = AnimatedPress(
      onTap: onPressed,
      scaleDown: 0.92,
      duration: AppMotion.fast,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: variant == IconButtonVariant.tonal
              ? AppSpacing.brMd
              : AppSpacing.brPill,
        ),
        child: iconWidget,
      ),
    );

    final wrapped = disabled ? Opacity(opacity: 0.4, child: btn) : btn;

    if (tooltip == null) return wrapped;
    return Tooltip(message: tooltip!, child: wrapped);
  }
}
