import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

enum PremiumButtonVariant { primary, secondary, ghost, destructive }

enum PremiumButtonSize { sm, md, lg }

/// The single button primitive. Four variants, three sizes, always with
/// a press-down micro-interaction and tasteful focus state.
class PremiumButton extends StatelessWidget {
  final String? label;
  final Widget? leading;
  final Widget? trailing;
  final PremiumButtonVariant variant;
  final PremiumButtonSize size;
  final VoidCallback? onPressed;
  final bool expand;
  final bool loading;

  const PremiumButton({
    super.key,
    this.label,
    this.leading,
    this.trailing,
    this.variant = PremiumButtonVariant.primary,
    this.size = PremiumButtonSize.md,
    this.onPressed,
    this.expand = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDisabled = onPressed == null || loading;

    final (bg, fg, border) = switch (variant) {
      PremiumButtonVariant.primary => (c.accent, c.onAccent, null),
      PremiumButtonVariant.secondary => (c.surface, c.textPrimary, c.border),
      PremiumButtonVariant.ghost => (Colors.transparent, c.textPrimary, null),
      PremiumButtonVariant.destructive => (
        Colors.transparent,
        Colors.white,
        null,
      ),
    };

    final (hPad, vPad, fontSize, iconSize) = switch (size) {
      PremiumButtonSize.sm => (12.0, 8.0, 13.0, 16.0),
      PremiumButtonSize.md => (16.0, 12.0, 14.0, 18.0),
      PremiumButtonSize.lg => (20.0, 16.0, 16.0, 20.0),
    };

    final radius = size == PremiumButtonSize.sm
        ? AppSpacing.brSm
        : (size == PremiumButtonSize.lg ? AppSpacing.brMd : AppSpacing.brMd);

    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border != null
            ? Border.all(color: border, width: 0.5)
            : variant == PremiumButtonVariant.destructive
            ? null
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            )
          else if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: fg, size: iconSize),
              child: leading!,
            ),
          ],
          if (label != null) ...[
            SizedBox(width: leading != null || loading ? 8 : 0),
            Flexible(
              child: Text(
                label!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data: IconThemeData(color: fg, size: iconSize),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    if (isDisabled) {
      return Opacity(opacity: 0.45, child: child);
    }
    return AnimatedPress(
      onTap: onPressed,
      scaleDown: 0.97,
      duration: AppMotion.fast,
      child: child,
    );
  }
}

extension on PremiumButtonVariant {
  // Reserved for future tweaks; intentional to avoid unused-field warning.
}

extension on PremiumButtonSize {
  // Reserved.
}
