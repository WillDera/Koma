import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'router/router.dart';

/// Kept for back-compat with any code that referenced the app's global
/// route observer. go_router manages its own navigator; screens that used
/// [routeObserver] for RouteAware didChangeDependencies still work because
/// we register it on the router's observer list.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class KomaApp extends ConsumerWidget {
  const KomaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProv = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Koma',
      debugShowCheckedModeBanner: false,
      theme: themeProv.isSepia ? themeProv.sepiaTheme : themeProv.lightTheme,
      darkTheme: themeProv.darkTheme,
      themeMode: themeProv.isSepia ? ThemeMode.light : themeProv.themeMode,
      routerConfig: appRouter,
    );
  }
}
