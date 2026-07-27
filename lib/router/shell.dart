import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_provider.dart';
import '../widgets/glass_pill_nav.dart';

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
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: 'Library',
    ),
    NavItem(
      icon: Icons.history,
      activeIcon: Icons.history,
      label: 'History',
    ),
    NavItem(
      icon: Icons.bookmark_outline,
      activeIcon: Icons.bookmark,
      label: 'Snippets',
    ),
    NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Discover',
    ),
    NavItem(
      icon: Icons.search,
      activeIcon: Icons.search,
      label: 'Search',
    ),
    NavItem(
      icon: Icons.tune,
      activeIcon: Icons.tune,
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
    );
  }
}
