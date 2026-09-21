import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/isar/isar.dart';
import 'core/providers.dart';
import 'core/repositories/repositories.dart';
import 'core/services/app_storage.dart';
import 'core/services/background_task.dart';
import 'core/services/extension_install_listener.dart';
import 'core/services/extension_manager.dart';
import 'core/services/extension_repo_deep_link_listener.dart';
import 'core/services/file_open_intent_listener.dart';
import 'core/services/continue_widget_service.dart';
import 'core/services/source_pref_store.dart';
import 'core/services/search_intent_listener.dart';
import 'core/services/security_prefs.dart';
import 'core/services/http/m_client.dart';
import 'core/services/keiyoushi_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/stats_service.dart';
import 'core/services/user_profile.dart';
import 'src/rust/frb_generated.dart';
import 'theme/theme_provider.dart';
import 'eval/model/m_bridge.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    await SecurityPrefs.load();
    // Prefer more, smaller decoded covers over a few full-res bitmaps.
    // Thumbnail paths decode near display size (see coverProvider /
    // BookCover.cacheWidth). Keep this tight — IndexedStack tabs keep images
    // "live", so a large budget becomes permanent RAM and hitchy navigation.
    final images = PaintingBinding.instance.imageCache;
    images.maximumSize = 120;
    images.maximumSizeBytes = 64 << 20; // 64 MiB
    // Keep the native LaunchTheme visible until startup work finishes
    // (flutter_native_splash is dev-only for asset generation).
    widgetsBinding.deferFirstFrame();
    try {
      // Extension chapter parsers use DateFormat(locale) for non-en sources;
      // without this, getDetail throws LocaleDataException on screen.
      await MBridge.ensureDateFormattingReady();

      // Rust metadata engine (Open Library / Google Books) via flutter_rust_bridge.
      await RustLib.init();
      await AppStorage.init();
      // PDFium worker isolate — PdfViewer.file hangs forever if this never
      // finishes (default loading banner is null, so it looks like a spinner
      // from the book FutureProvider, or a blank grey viewer).
      unawaited(pdfrxFlutterInitialize());

      // WorkManager periodic polling (library updates). Initialized once so the
      // native side can wake the Dart callback in a background isolate.
      unawaited(Workmanager().initialize(backgroundCallbackDispatcher));
      // System notifications (library + extension updates).
      unawaited(NotificationService.instance.init());

      final isar = await openIsar();
      SourcePrefStore.bind(isar);
      final repos = Repositories(isar);

      // Wire the Cloudflare / cookie HTTP pipeline (mangayomi parity): the
      // intercepted client reads cookies through MClient.cookies, and the local
      // loopback server drives the headless-WebView challenge solver.
      MClient.cookies = repos.cookies;
      unawaited(webviewServer());
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final availableVersion =
            await webview.WebViewEnvironment.getAvailableVersion();
        if (availableVersion != null) {
          final document = await AppStorage.documents();
          webViewEnvironment = await webview.WebViewEnvironment.create(
            settings: webview.WebViewEnvironmentSettings(
              userDataFolder: p.join(document.path, 'flutter_inappwebview'),
            ),
          );
        }
      }

      final statsService = StatsService(repos);

      final keiyoushiService = KeiyoushiService();
      final extensionManager = ExtensionManager(
        repos,
        keiyoushiService,
      );
      ExtensionInstallListener.init(extensionManager);
      SearchIntentListener.init();

      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar),
          statsServiceProvider.overrideWithValue(statsService),
          keiyoushiServiceProvider.overrideWithValue(keiyoushiService),
          extensionManagerProvider.overrideWithValue(extensionManager),
        ],
      );
      FileOpenIntentListener.init(container);
      ExtensionRepoDeepLinkListener.init(container);
      ContinueWidgetService.init(container);

      unawaited(extensionManager.reloadAll().then((_) async {
        await _checkExtensionUpdates(extensionManager);
        try {
          await container.read(extensionUpdateCountProvider.notifier).refresh();
          final count = container.read(extensionUpdateCountProvider);
          if (count > 0) {
            await NotificationService.instance.notifyExtensionUpdates(count);
          }
        } catch (_) {}
      }));

      // Initialize Notifiers that need SharedPreferences loaded before
      // first paint. The Notifier instances are created by the container
      // automatically — we just call their init() methods.
      try {
        await container.read(themeProvider.notifier).init();
      } catch (e) {
        debugPrint('theme init skipped: $e');
      }
      try {
        await container.read(userProfileProvider.notifier).load();
      } catch (e) {
        debugPrint('user profile init skipped: $e');
      }
      try {
        await container.read(libraryProvider.notifier).init();
      } catch (e) {
        debugPrint('library init skipped: $e');
      }
      // Start the library chapter poller (reads its enabled/interval prefs and
      // schedules a periodic check if auto-update is on).
      try {
        await container.read(libraryUpdateProvider.notifier).init();
      } catch (e) {
        debugPrint('library update init skipped: $e');
      }
      // Restore persisted chapter download queue (Mihon DownloadStore parity).
      unawaited(container.read(downloadManagerProvider.notifier).restore());

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const KomaApp(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Startup failed: $e\n$stack');
      runApp(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText('Startup failed:\n$e'),
              ),
            ),
          ),
        ),
      );
    } finally {
      widgetsBinding.allowFirstFrame();
    }
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

Future<void>? _extensionUpdatesInFlight;

/// Check all repos for extension updates and store versionLast flags.
/// Ported from mangayomi's fetchItemSourcesListProvider on app start.
/// When `extension_auto_update_enabled` is set, also downloads replacements
/// (Mangayomi autoUpdateExtensions parity).
Future<void> _checkExtensionUpdates(ExtensionManager mgr) {
  final inFlight = _extensionUpdatesInFlight;
  if (inFlight != null) return inFlight;
  final future = _checkExtensionUpdatesBody(mgr);
  _extensionUpdatesInFlight = future;
  return future.whenComplete(() {
    if (identical(_extensionUpdatesInFlight, future)) {
      _extensionUpdatesInFlight = null;
    }
  });
}

Future<void> _checkExtensionUpdatesBody(ExtensionManager mgr) async {
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
