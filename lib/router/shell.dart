import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_icons.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_pill_nav.dart';
import '../widgets/nav_drawer.dart';

/// The bottom-nav shell. Wraps go_router's [StatefulNavigationShell]
/// (an IndexedStack of the six tab branches, each with its own Navigator
/// and preserved state) and renders the [GlassPillNav] over it.
///
/// Replaces the old hand-rolled Stack+IgnorePointer+AnimatedOpacity shell
/// from app.dart. Tab switching now goes through `navigationShell.goBranch`,
/// which keeps every branch alive — same state-preservation guarantee as
/// before, but with real per-tab navigation history.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _navItems = [
    NavItem(
      icon: AppIcons.library,
      activeIcon: AppIcons.libraryActive,
      label: 'Library',
    ),
    NavItem(
      icon: AppIcons.history,
      activeIcon: AppIcons.historyActive,
      label: 'History',
    ),
    NavItem(
      icon: AppIcons.snippets,
      activeIcon: AppIcons.snippetsActive,
      label: 'Snippets',
    ),
    NavItem(
      icon: AppIcons.discover,
      activeIcon: AppIcons.discoverActive,
      label: 'Discover',
    ),
    NavItem(
      icon: AppIcons.search,
      activeIcon: AppIcons.searchActive,
      label: 'Search',
    ),
    NavItem(
      icon: AppIcons.settings,
      activeIcon: AppIcons.settingsActive,
      label: 'Settings',
    ),
  ];

  void _onTap(int index) {
    // goBranch with initialLocation:true when re-tapping the active tab
    // pops that branch to its root — matches common bottom-nav UX.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return Scaffold(
      extendBody: true,
      backgroundColor: theme.bgColor,
      body: navigationShell,
      bottomNavigationBar: GlassPillNav(
        items: _navItems,
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
      drawer: NavDrawer(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        version: '2.27.3',
      ),
    );
  }
}
