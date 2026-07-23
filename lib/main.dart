import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/database_service.dart';
import 'core/services/extension_manager.dart';
import 'core/services/keiyoushi_service.dart';
import 'core/services/stats_service.dart';
import 'features/library/library_provider.dart';
import 'features/reader/reader_provider.dart';
import 'features/snippets/snippets_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = await DatabaseService.getInstance();
  final statsService = StatsService(dbService);
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final libraryProvider = LibraryProvider(dbService);
  await libraryProvider.init();
  final readerProvider = ReaderProvider(dbService, statsService);
  final snippetsProvider = SnippetsProvider(dbService, statsService);

  // Re-mount any extensions the user previously installed so the
  // native Keiyoushi bridge has them loaded for this session.
  // Fire-and-forget — failures don't block the UI.
  final keiyoushiService = KeiyoushiService();
  final extensionManager = ExtensionManager(dbService, keiyoushiService);
  unawaited(extensionManager.reloadAll());

  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        Provider<StatsService>.value(value: statsService),
        Provider<KeiyoushiService>.value(value: keiyoushiService),
        Provider<ExtensionManager>.value(value: extensionManager),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
        ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
        ChangeNotifierProvider<SnippetsProvider>.value(value: snippetsProvider),
      ],
      child: const KomaApp(),
    ),
  );

  // whenever your initialization is completed, remove the splash screen:
  FlutterNativeSplash.remove();
}
