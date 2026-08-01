import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import '../theme/tokens/app_type.dart';
import 'animated_press.dart';

class NavDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String version;

  const NavDrawer({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.version,
  });

  static const _items = [
    DrawerNavItem(
      icon: AppIcons.library,
      activeIcon: AppIcons.libraryActive,
      label: 'Library',
    ),
    DrawerNavItem(
      icon: AppIcons.history,
      activeIcon: AppIcons.historyActive,
      label: 'History',
    ),
    DrawerNavItem(
      icon: AppIcons.snippets,
      activeIcon: AppIcons.snippetsActive,
      label: 'Snippets',
    ),
    DrawerNavItem(
      icon: AppIcons.discover,
      activeIcon: AppIcons.discoverActive,
      label: 'Discover',
    ),
    DrawerNavItem(
      icon: AppIcons.search,
      activeIcon: AppIcons.searchActive,
      label: 'Search',
    ),
    DrawerNavItem(
      icon: AppIcons.settings,
      activeIcon: AppIcons.settingsActive,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Drawer(
      backgroundColor: c.bgElevated,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              MediaQuery.of(context).padding.top + AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koma',
                  style: TextStyle(
                    fontFamily: AppType.uiFont,
                    fontSize: 22,
                    height: 28 / 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cinematic Neo-Noir',
                  style: AppType.labelCaps(fontSize: 12, color: c.textTertiary),
                ),
              ],
            ),
          ),

          // Nav items
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final active = i == currentIndex;
                return _NavTile(
                  icon: active ? item.activeIcon : item.icon,
                  label: item.label,
                  active: active,
                  onTap: () {
                    onTap(i);
                    if (context.canPop()) Navigator.of(context).pop();
                  },
                );
              }),
            ),
          ),

          const Spacer(),

          // Footer
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              MediaQuery.of(context).padding.bottom + AppSpacing.lg,
            ),
            child: Text(
              'Version $version',
              style: AppType.mono(fontSize: 11, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class DrawerNavItem {
  final AppIconData icon;
  final AppIconData activeIcon;
  final String label;

  const DrawerNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavTile extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? c.accentMuted : Colors.transparent,
          borderRadius: AppSpacing.brLg,
        ),
        child: Row(
          children: [
            AppIcon(
              data: icon,
              size: 22,
              color: active ? c.accent : c.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppType.labelCaps(
                fontSize: 13,
                color: active ? c.accent : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
