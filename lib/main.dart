import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/isar/isar.dart';
import 'core/providers.dart';
import 'core/repositories/repositories.dart';
import 'core/services/extension_manager.dart';
import 'core/services/keiyoushi_service.dart';
import 'core/services/stats_service.dart';
import 'theme/theme_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isar = await openIsar();

  final statsService = StatsService(Repositories(isar));

  final keiyoushiService = KeiyoushiService();
  final extensionManager = ExtensionManager(
    Repositories(isar),
    keiyoushiService,
  );
  unawaited(extensionManager.reloadAll().then((_) {
    unawaited(_checkExtensionUpdates(extensionManager));
  }));

  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final container = ProviderContainer(
    overrides: [
      isarProvider.overrideWithValue(isar),
      statsServiceProvider.overrideWithValue(statsService),
      keiyoushiServiceProvider.overrideWithValue(keiyoushiService),
      extensionManagerProvider.overrideWithValue(extensionManager),
    ],
  );

  // Initialize Notifiers that need SharedPreferences loaded before
  // first paint. The Notifier instances are created by the container
  // automatically — we just call their init() methods.
  await container.read(themeProvider.notifier).init();
  await container.read(libraryProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KomaApp(),
    ),
  );

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
