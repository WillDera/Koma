import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_lock_service.dart';
import 'core/services/security_prefs.dart';
import 'router/router.dart';
import 'theme/theme_provider.dart';
import 'widgets/app_lock_overlay.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class KomaApp extends ConsumerStatefulWidget {
  const KomaApp({super.key});

  @override
  ConsumerState<KomaApp> createState() => _KomaAppState();
}

class _KomaAppState extends ConsumerState<KomaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSecureScreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (ref.read(appLockEnabledProvider)) {
        ref.read(appUnlockedProvider.notifier).lock();
      }
    }
    if (state == AppLifecycleState.resumed) {
      _syncSecureScreen();
    }
  }

  Future<void> _syncSecureScreen() async {
    await AppLockService.applySecureScreen(
      mode: ref.read(secureScreenProvider),
      incognito: ref.read(incognitoProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final unlocked = ref.watch(appUnlockedProvider);
    final lockOn = ref.watch(appLockEnabledProvider);
    ref.listen(incognitoProvider, (_, _) => _syncSecureScreen());
    ref.listen(secureScreenProvider, (_, _) => _syncSecureScreen());

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lp = lightDynamic?.primary;
        final dp = darkDynamic?.primary;
        if (lp != theme.lightDynamicPrimary ||
            dp != theme.darkDynamicPrimary) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.setDynamicColorSchemes(lightDynamic, darkDynamic);
          });
        }

        return MaterialApp.router(
          title: 'Koma',
          debugShowCheckedModeBanner: false,
          theme: theme.isSepia ? notifier.sepiaTheme : notifier.lightTheme,
          darkTheme: notifier.darkTheme,
          themeMode: theme.isSepia ? ThemeMode.light : theme.themeMode,
          routerConfig: appRouter,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (child != null) child,
                if (lockOn && !unlocked) const AppLockOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}
