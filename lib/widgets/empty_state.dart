import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'premium_button.dart';

/// A refined empty state. Icon (line, 1.5px stroke feel), title, subtitle,
/// optional primary CTA. Used on Library / Snippets / Search.
class EmptyState extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String? subtitle;
  final String? primaryActionLabel;
  final AppIconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: AppSpacing.brLg,
              ),
              child: Center(
                child: AppIcon(data: icon, size: 28, color: c.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 28),
              PremiumButton(
                label: primaryActionLabel,
                leading: primaryActionIcon != null
                    ? AppIcon(data: primaryActionIcon!, size: 20)
                    : null,
                onPressed: onPrimaryAction,
                size: PremiumButtonSize.lg,
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              AnimatedPress(
                onTap: onSecondaryAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    secondaryActionLabel!,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
