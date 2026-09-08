import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_version.dart';
import '../core/services/user_profile.dart';
import '../theme/app_icons.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_update_gate.dart';
import '../widgets/glass_pill_nav.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/stats_popup.dart';

/// The bottom-nav shell. Wraps go_router's [StatefulNavigationShell]
/// (an IndexedStack of the five tab branches, each with its own Navigator
/// and preserved state) and renders the [AppBottomNav] under it.
///
/// Kenji tab order: Library → Updates → History → Explore → You.
/// Snippets lives as a pushed route (Settings / library entry).
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
      icon: AppIcons.updates,
      activeIcon: AppIcons.updatesActive,
      label: 'Updates',
    ),
    NavItem(
      icon: AppIcons.history,
      activeIcon: AppIcons.historyActive,
      label: 'History',
    ),
    NavItem(
      icon: AppIcons.discover,
      activeIcon: AppIcons.discoverActive,
      label: 'Explore',
    ),
    NavItem(
      icon: AppIcons.settings,
      activeIcon: AppIcons.settingsActive,
      label: 'You',
      profileTab: true,
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
    final profile = ref.watch(userProfileProvider);
    final initials = profile.firstName.isNotEmpty
        ? profile.firstName
        : (profile.displayName.isNotEmpty ? profile.displayName : 'K');
    final profileImage = profile.hasAvatar
        ? FileImage(File(profile.avatarPath!))
        : null;
    final version = ref.watch(packageInfoProvider).when(
          data: (info) => '${info.version}+${info.buildNumber}',
          loading: () => '',
          error: (_, _) => '',
        );
    final onLibrary = navigationShell.currentIndex == 0;
    return AppUpdateGate(
      // Tab roots (Updates / History / Explore / You) have nothing to pop, so
      // the system back gesture would finish the Activity. Send those to
      // Library instead; Library root still exits as usual. Detail routes
      // pushed above the shell keep normal pop behavior.
      child: PopScope(
        canPop: onLibrary,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (navigationShell.currentIndex != 0) {
            navigationShell.goBranch(0);
          }
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: theme.bgColor,
          body: navigationShell,
          bottomNavigationBar: AppBottomNav(
            items: _navItems,
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
            onLongPress: (index) {
              if (!_navItems[index].profileTab) return;
              showStatsPopup(context);
            },
            profileInitials: initials,
            profileImage: profileImage,
          ),
          drawer: NavDrawer(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
            version: version,
          ),
        ),
      ),
    );
  }
}
