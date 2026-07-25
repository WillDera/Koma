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
  final keiyoushiService = KeiyoushiService();
  final extensionManager = ExtensionManager(dbService, keiyoushiService);
  unawaited(extensionManager.reloadAll().then((_) {
    // Check for extension updates on start (mangayomi pattern).
    unawaited(_checkExtensionUpdates(extensionManager));
  }));

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

/// Check all repos for extension updates and store versionLast flags.
/// Ported from mangayomi's fetchItemSourcesListProvider on app start.
Future<void> _checkExtensionUpdates(ExtensionManager mgr) async {
  try {
    final repos = await mgr.listRepos();
    for (final repo in repos) {
      if (!repo.enabled) continue;
      try {
        final entries = await mgr.fetchIndex(repo);
        await mgr.checkForUpdates(entries, repo.url);
        await mgr.checkForObsoleteSources(entries, repo.url);
      } catch (_) {
        // One repo failing shouldn't block the others (mangayomi pattern).
      }
    }
  } catch (_) {}
}
