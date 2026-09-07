import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'premium_button.dart';

/// Empty state used across Library / Snippets / Search.
///
/// Kenji-style: optional [emoji] in a circular well, larger title, and a
/// full-width stadium primary CTA when [pillPrimary] is true.
class EmptyState extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String? subtitle;
  final String? emoji;
  final String? primaryActionLabel;
  final AppIconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool pillPrimary;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.emoji,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.pillPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pillPrimary ? 24 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji!, style: const TextStyle(fontSize: 40)),
              )
            else
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
            SizedBox(height: emoji != null ? 24 : 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: emoji != null ? 20 : 15,
                fontWeight: FontWeight.w500,
                letterSpacing: emoji != null ? -0.5 : 0,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: emoji != null ? 14 : 12,
                  height: 1.4,
                ),
              ),
            ],
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              SizedBox(height: pillPrimary ? 40 : 28),
              if (pillPrimary)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: onPrimaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(primaryActionLabel!),
                  ),
                )
              else
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
