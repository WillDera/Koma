import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/discover/discover_screen.dart';
import 'features/history/history_screen.dart';
import 'features/library/library_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/snippets/snippets_screen.dart';
import 'theme/theme_provider.dart';
import 'theme/tokens/app_motion.dart';
import 'widgets/glass_pill_nav.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class KomaApp extends StatelessWidget {
  const KomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Koma',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: themeProv.isSepia ? themeProv.sepiaTheme : themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      themeMode:
          themeProv.isSepia ? ThemeMode.light : themeProv.themeMode,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    LibraryScreen(),
    HistoryScreen(),
    SnippetsScreen(),
    DiscoverScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];

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

  void _onTap(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    return Scaffold(
      extendBody: true,
      backgroundColor: themeProv.bgColor,
      body: Stack(
        children: [
          // All tab screens stay mounted in the tree at full size so their
          // state is preserved across tab switches. Inactive tabs are
          // hidden visually with Opacity and excluded from hit-testing
          // with IgnorePointer. We deliberately avoid IndexedStack/Offstage
          // here because those give off-screen children Size.zero
          // constraints, which breaks Column + Expanded layouts (and trips
          // a "cannot hit-test a render box with no size" assertion when
          // any pointer event arrives while an off-screen tab contains
          // a flex child waiting for a size).
          for (var i = 0; i < _screens.length; i++)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: i != _currentIndex,
                child: AnimatedOpacity(
                  duration: AppMotion.base,
                  opacity: i == _currentIndex ? 1 : 0,
                  child: TickerMode(
                    enabled: i == _currentIndex,
                    child: _screens[i],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: GlassPillNav(
        items: _navItems,
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
