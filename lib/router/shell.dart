import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_version.dart';
import '../core/services/security_prefs.dart';
import '../core/services/user_profile.dart';
import '../features/library/library_nav_satellite.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../theme/theme_state.dart';
import '../widgets/app_update_gate.dart';
import '../widgets/glass_pill_nav.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/stats_popup.dart';

/// When true, a tab is consuming system back for in-tab history (Library
/// section view-all, Explore search / view-all, …). [MainShell] must not exit
/// the app or jump tabs — nested [PopScope]s with `canPop: false` alone are
/// not enough because the shell route is a separate navigator entry.
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

/// True while a full-screen overlay (For You → View more) should push the
/// pill nav off the bottom of the screen.
class ShellBottomBarHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state == value) return;
    state = value;
  }
}

final shellBottomBarHiddenProvider =
    NotifierProvider<ShellBottomBarHidden, bool>(ShellBottomBarHidden.new);

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
    final leftHanded = ref.watch(themeProvider).handMode == HandMode.left;
    final satellite = ref.watch(libraryNavSatelliteProvider);
    final hideBottomBar = ref.watch(shellBottomBarHiddenProvider);
    final c = context.colors;
    return AppUpdateGate(
      child: PopScope(
        // Library root may exit the app, unless Library itself is consuming
        // back for section view-all (via [shellBackInterceptorProvider]).
        canPop: onLibrary && !tabConsumesBack,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // IndexedStack keeps other tabs alive — only honor the interceptor
          // for the tab that actually claims it (Library / Explore).
          final i = navigationShell.currentIndex;
          if (tabConsumesBack && (i == 0 || i == 3)) return;
          if (i != 0) {
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
          bottomNavigationBar: AnimatedSlide(
            offset: hideBottomBar ? const Offset(0, 1.6) : Offset.zero,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeInOutCubic,
            child: AppBottomNav(
              items: _navItems,
              currentIndex: navigationShell.currentIndex,
              onTap: _onTap,
              onLongPress: (index) {
                if (!_navItems[index].profileTab) return;
                showStatsPopup(context);
              },
              profileInitials: initials,
              profileImage: profileImage,
              satelliteLeading: leftHanded,
              satellite: onLibrary && satellite.hasAny
                  ? _LibraryNavSatelliteCluster(satellite: satellite)
                  : null,
            ),
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

class _LibraryNavSatelliteCluster extends StatelessWidget {
  const _LibraryNavSatelliteCluster({required this.satellite});

  final LibraryNavSatellite satellite;

  @override
  Widget build(BuildContext context) {
    final hide = satellite.onHideSelected;
    final add = satellite.onAdd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hide != null) ...[
          NavSatelliteButton(
            icon: const MaterialIconData(Icons.visibility_off_outlined),
            tooltip: 'Hide selected',
            onPressed: hide,
          ),
          if (add != null) const SizedBox(height: 10),
        ],
        if (add != null)
          NavSatelliteButton(
            icon: AppIcons.add,
            tooltip: 'Add',
            emphasized: true,
            onPressed: add,
          ),
      ],
    );
  }
}
