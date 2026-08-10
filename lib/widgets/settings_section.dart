import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'divider_hairline.dart';

/// A wrapper used for Settings screen sections. Figma "ReadLoom" styling:
/// flat surface card (16px radius, hairline border) with a small uppercase
/// section header above.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;
  final bool showHeader;
  final String? footer;
  final Color? headerColor;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.showHeader = true,
    this.footer,
    this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: headerColor ?? c.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppSpacing.brLg,
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(children: _withDividers(children)),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    if (items.isEmpty) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: HairlineDivider(),
          ),
        );
      }
    }
    return out;
  }
}

/// A row inside a settings section. Figma menu-row styling: rounded-xl
/// icon tile tinted with [iconColor], 14px/w500 title, 11px muted subtitle.
class SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final Color? iconColor;

  const SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = destructive ? const Color(0xFFC44C4C) : c.textPrimary;
    final tint = destructive
        ? const Color(0xFFC44C4C)
        : (iconColor ?? c.accent);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.13),
                borderRadius: AppSpacing.brMd,
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null) ...[
            Icon(Icons.chevron_right, size: 18, color: c.textTertiary),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.99,
      child: Material(type: MaterialType.transparency, child: row),
    );
  }
}
