import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/isar/isar.dart';
import 'core/providers.dart';
import 'core/repositories/repositories.dart';
import 'core/services/background_task.dart';
import 'core/services/extension_manager.dart';
import 'core/services/http/m_client.dart';
import 'core/services/keiyoushi_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/stats_service.dart';
import 'src/rust/frb_generated.dart';
import 'theme/theme_provider.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    if (kReleaseMode) {
      throw details.exception;
    }
  };

  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    // Keep the native LaunchTheme visible until startup work finishes
    // (flutter_native_splash is dev-only for asset generation).
    widgetsBinding.deferFirstFrame();

    // Rust metadata engine (Open Library / Google Books) via flutter_rust_bridge.
    await RustLib.init();

    // WorkManager periodic polling (library updates). Initialized once so the
    // native side can wake the Dart callback in a background isolate.
    unawaited(Workmanager().initialize(backgroundCallbackDispatcher));
    // System notifications (library + extension updates).
    unawaited(NotificationService.instance.init());

    final isar = await openIsar();
      final repos = Repositories(isar);

      // Wire the Cloudflare / cookie HTTP pipeline (mangayomi parity): the
    // intercepted client reads cookies through MClient.cookies, and the local
    // loopback server drives the headless-WebView challenge solver.
    MClient.cookies = repos.cookies;
    unawaited(webviewServer());
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final availableVersion = await webview.WebViewEnvironment
          .getAvailableVersion();
      if (availableVersion != null) {
        final document = await getApplicationDocumentsDirectory();
        webViewEnvironment = await webview.WebViewEnvironment.create(
          settings: webview.WebViewEnvironmentSettings(
            userDataFolder: p.join(document.path, 'flutter_inappwebview'),
          ),
        );
      }
    }

    final statsService = StatsService(repos);

    final keiyoushiService = KeiyoushiService();
    final extensionManager = ExtensionManager(repos, keiyoushiService,
    );
    unawaited(extensionManager.reloadAll().then((_) {
      unawaited(_checkExtensionUpdates(extensionManager));
    }));


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
    // Start the library chapter poller (reads its enabled/interval prefs and
    // schedules a periodic check if auto-update is on).
    await container.read(libraryUpdateProvider.notifier).init();
    // Restore persisted chapter download queue (Mihon DownloadStore parity).
    unawaited(container.read(downloadManagerProvider.notifier).restore());

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const KomaApp(),
      ),
    );

    widgetsBinding.allowFirstFrame();

    // Surface the extension-update badge once the startup index check has
    // written versionLast flags for every repo (mangayomi parity: it shows a
    // system notification when updates are found on app start).
    unawaited(_checkExtensionUpdates(extensionManager).then((_) async {
      try {
        await container.read(extensionUpdateCountProvider.notifier).refresh();
        final count = container.read(extensionUpdateCountProvider);
        if (count > 0) {
          await NotificationService.instance.notifyExtensionUpdates(count);
        }
      } catch (_) {}
    }));
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

/// Check all repos for extension updates and store versionLast flags.
/// Ported from mangayomi's fetchItemSourcesListProvider on app start.
/// When `extension_auto_update_enabled` is set, also downloads replacements
/// (Mangayomi autoUpdateExtensions parity).
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
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('extension_auto_update_enabled') ?? false) {
      await mgr.autoInstallAvailableUpdates();
    }
  } catch (_) {}
}
