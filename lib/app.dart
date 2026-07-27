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

    return MaterialApp.router(
      title: 'Koma',
      debugShowCheckedModeBanner: false,
      theme: theme.isSepia ? notifier.sepiaTheme : notifier.lightTheme,
      darkTheme: notifier.darkTheme,
      themeMode: theme.isSepia ? ThemeMode.light : theme.themeMode,
      routerConfig: appRouter,
    );
  }
}
