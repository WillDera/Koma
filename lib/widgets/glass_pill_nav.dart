import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';

class NavItem {
  final AppIconData icon;
  final AppIconData? activeIcon;
  final String label;

  /// When true, [AppBottomNav.profileInitials] renders instead of [icon].
  final bool profileTab;

  const NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.profileTab = false,
  });
}

/// Flat bottom navigation — Kenji-inspired opaque bar with accent active
/// tint. The optional profile tab shows an initials / photo avatar ("You").
class AppBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onLongPress;
  final String? profileInitials;
  final ImageProvider? profileImage;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onLongPress,
    this.profileInitials,
    this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    onLongPress: onLongPress == null
                        ? null
                        : () => onLongPress!(i),
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: Curves.easeOutBack,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isActive ? 1.0 : 0.9,
                            duration: AppMotion.base,
                            curve: Curves.easeOutBack,
                            child: _NavGlyph(
                              item: item,
                              isActive: isActive,
                              initials: item.profileTab
                                  ? profileInitials
                                  : null,
                              image: item.profileTab ? profileImage : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedDefaultTextStyle(
                            duration: AppMotion.base,
                            curve: Curves.easeOutBack,
                            style: TextStyle(
                              color: isActive
                                  ? c.accent
                                  : c.textTertiary,
                              fontSize: 12,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({
    required this.item,
    required this.isActive,
    required this.initials,
    this.image,
  });

  final NavItem item;
  final bool isActive;
  final String? initials;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (initials != null || image != null) {
      final trimmed = (initials ?? '').trim();
      final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
      return AnimatedContainer(
        duration: AppMotion.base,
        curve: Curves.easeOutBack,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? c.accent : c.surfaceMuted,
          border: Border.all(
            color: isActive ? c.accent : c.borderStrong,
            width: 1.5,
          ),
          image: image != null
              ? DecorationImage(image: image!, fit: BoxFit.cover)
              : null,
        ),
        child: image != null
            ? null
            : Text(
                letter,
                style: TextStyle(
                  color: isActive ? c.onAccent : c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      );
    }

    return AnimatedContainer(
      duration: AppMotion.base,
      curve: Curves.easeOutBack,
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive
            ? c.accent.withValues(alpha: 0.26)
            : Colors.transparent,
        borderRadius: AppSpacing.brMd,
      ),
      child: AppIcon(
        data: isActive ? (item.activeIcon ?? item.icon) : item.icon,
        size: 22,
        color: isActive ? c.accent : c.textTertiary,
      ),
    );
  }
}
