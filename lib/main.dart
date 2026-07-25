import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/isar/isar.dart';
import 'core/isar/migration/drift_isar_migration.dart';
import 'core/providers.dart';
import 'core/services/database_service.dart';
import 'core/services/extension_manager.dart';
import 'core/services/keiyoushi_service.dart';
import 'core/services/stats_service.dart';
import 'features/library/library_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = await DatabaseService.getInstance();

  // Open Isar (PHASE 1) and run the one-time Drift→Isar migration. Runs
  // silently on first launch after the user upgrades to a build that
  // includes Isar. No-op on subsequent launches (gated by a
  // SharedPreferences flag). Errors are non-fatal — the app still works.
  final isar = await openIsar();
  try {
    final report = await migrateDriftToIsar(dbService, isar: isar);
    assert(() {
      // ignore: avoid_print
      print('Isar migration: $report');
      return true;
    }());
  } catch (_) {
    // Migration failed — log and continue.
  }

  final statsService = StatsService(dbService);
  final themeProv = ThemeProvider();
  await themeProv.init();

  final libraryProv = LibraryProvider(dbService);
  await libraryProv.init();

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
    ProviderScope(
      overrides: [
        // Heavy singletons created once at startup are injected here so
        // the whole provider graph shares one instance. ThemeProvider and
        // LibraryProvider are pre-initialized (init() awaited above) so
        // their persisted prefs are ready before first paint.
        isarProvider.overrideWithValue(isar),
        databaseServiceProvider.overrideWithValue(dbService),
        statsServiceProvider.overrideWithValue(statsService),
        keiyoushiServiceProvider.overrideWithValue(keiyoushiService),
        extensionManagerProvider.overrideWithValue(extensionManager),
        themeProvider.overrideWith((ref) => themeProv),
        libraryProvider.overrideWith((ref) => libraryProv),
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
