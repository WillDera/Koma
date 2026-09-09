import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_version.dart';
import '../core/services/security_prefs.dart';
import '../core/services/user_profile.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_update_gate.dart';
import '../widgets/glass_pill_nav.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/stats_popup.dart';

/// When true, Explore is consuming system back for in-tab history (view-all /
/// search). [MainShell] must not also jump to Library — nested [PopScope]s with
/// `canPop: false` all receive the same pop attempt.
class ShellBackInterceptor extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state == value) return;
    state = value;
  }
}

final shellBackInterceptorProvider =
    NotifierProvider<ShellBackInterceptor, bool>(ShellBackInterceptor.new);

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
    final incognito = ref.watch(incognitoProvider);
    final tabConsumesBack = ref.watch(shellBackInterceptorProvider);
    final c = context.colors;
    return AppUpdateGate(
      child: PopScope(
        canPop: onLibrary,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // Explore (and similar) may consume back for in-tab history. Only
          // honor that while that branch is actually showing — IndexedStack
          // keeps other tabs alive with a stale interceptor flag.
          if (navigationShell.currentIndex == 3 && tabConsumesBack) return;
          if (navigationShell.currentIndex != 0) {
            navigationShell.goBranch(0);
          }
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: theme.bgColor,
          body: Column(
            children: [
              if (incognito)
                Material(
                  color: c.accent.withValues(alpha: 0.15),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off, size: 16, color: c.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Incognito — history and progress are not saved',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.read(incognitoProvider.notifier).set(false),
                            child: Text(
                              'Turn off',
                              style: TextStyle(color: c.accent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: navigationShell),
            ],
          ),
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
