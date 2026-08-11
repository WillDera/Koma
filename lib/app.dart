import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/router.dart';
import 'theme/theme_provider.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class KomaApp extends ConsumerWidget {
  const KomaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

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
        );
      },
    );
  }
}
