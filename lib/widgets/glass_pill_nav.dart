import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';

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

/// Floating animated pill bottom navigation.
///
/// Hugs its destinations (never full-width). The active destination expands;
/// inactive ones shrink. Labels are semantic-only — nothing is drawn as text.
class AppBottomNav extends StatelessWidget {
  /// Approximate body height of the floating pill (excludes safe-area inset).
  /// Used by screens that pad content above the bar.
  static const double bodyHeight = 56;

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

  static const Duration _duration = AppMotion.base;
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + bottomInset),
      // heightFactor keeps this as tall as the pill. Plain [Align] expands to
      // the Scaffold's max bottom-nav height, which then makes floating
      // SnackBars assert "presented off screen".
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Material(
          color: c.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: c.border.withValues(alpha: 0.55),
                width: 0.5,
              ),
            ),
            child: AnimatedSize(
              duration: _duration,
              curve: _curve,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (i) {
                    final item = items[i];
                    final isActive = i == currentIndex;
                    return _PillDestination(
                      key: ValueKey('nav-$i-${item.label}'),
                      item: item,
                      isActive: isActive,
                      onTap: () => onTap(i),
                      onLongPress: onLongPress == null
                          ? null
                          : () => onLongPress!(i),
                      profileInitials:
                          item.profileTab ? profileInitials : null,
                      profileImage: item.profileTab ? profileImage : null,
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillDestination extends StatelessWidget {
  const _PillDestination({
    super.key,
    required this.item,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
    this.profileInitials,
    this.profileImage,
  });

  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? profileInitials;
  final ImageProvider? profileImage;

  static const Duration _duration = AppMotion.base;
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeColor = c.accent;
    final inactiveColor = c.textTertiary;

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(22),
            splashColor: activeColor.withValues(alpha: 0.12),
            highlightColor: activeColor.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: _duration,
              curve: _curve,
              width: isActive ? 58 : 44,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: AnimatedScale(
                scale: isActive ? 1.0 : 0.82,
                duration: _duration,
                curve: _curve,
                child: _NavGlyph(
                  item: item,
                  isActive: isActive,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  initials: profileInitials,
                  image: profileImage,
                ),
              ),
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
    required this.activeColor,
    required this.inactiveColor,
    required this.initials,
    this.image,
  });

  final NavItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final String? initials;
  final ImageProvider? image;

  static const Duration _duration = AppMotion.base;
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (initials != null || image != null) {
      final trimmed = (initials ?? '').trim();
      final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
      final size = isActive ? 28.0 : 22.0;
      return AnimatedContainer(
        duration: _duration,
        curve: _curve,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor : inactiveColor.withValues(alpha: 0.2),
          border: Border.all(
            color: isActive ? activeColor : inactiveColor,
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
                  color: isActive ? c.onAccent : inactiveColor,
                  fontSize: isActive ? 12 : 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
      );
    }

    final iconData = isActive ? (item.activeIcon ?? item.icon) : item.icon;
    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: _curve,
      switchOutCurve: _curve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: AppIcon(
        key: ValueKey('${item.label}-$isActive'),
        data: iconData,
        size: isActive ? 24 : 20,
        color: isActive ? activeColor : inactiveColor,
      ),
    );
  }
}
