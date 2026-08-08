import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../eval/dispatch_service.dart';
import '../features/library/library_provider.dart';
import '../features/reader/reader_provider.dart';
import '../features/snippets/snippets_provider.dart';
import 'repositories/repositories.dart';
import 'services/download/chapter_download.dart';
import 'services/download/download_manager.dart';
import 'services/ebook_service.dart';
import 'services/extension_manager.dart';
import 'services/keiyoushi_service.dart';
import 'services/library_update_service.dart';
import 'services/search_service.dart';
import 'services/source_service.dart';
import 'services/stats_service.dart';

// themeProvider is defined in theme/theme_provider.dart and re-exported
// from there. Import it where needed, not from this file.

// ── Singletons (overridden at the root ProviderScope) ────────────────

final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider must be overridden'),
);

final repositoriesProvider = Provider<Repositories>(
  (ref) => Repositories(ref.watch(isarProvider)),
);

final statsServiceProvider = Provider<StatsService>(
  (ref) => StatsService(ref.watch(repositoriesProvider)),
);

final searchServiceProvider = Provider<SearchService>(
  (ref) => SearchService(ref.watch(repositoriesProvider)),
);

final sourceServiceProvider = Provider<SourceService>(
  (ref) => SourceService(ref.watch(repositoriesProvider), EbookService()),
);

final keiyoushiServiceProvider = Provider<KeiyoushiService>(
  (ref) => KeiyoushiService(),
);

final extensionServiceProvider = Provider<ExtensionDispatchService>(
  (ref) => ExtensionDispatchService(
    keiyoushiService: ref.watch(keiyoushiServiceProvider),
  ),
);

/// Snapshot of the global chapter download queue for Riverpod rebuilds.
class DownloadQueueSnapshot {
  const DownloadQueueSnapshot({
    required this.queue,
    required this.isRunning,
    required this.isPaused,
  });

  final List<ChapterDownload> queue;
  final bool isRunning;
  final bool isPaused;

  int get pendingCount =>
      queue.where((d) => d.status != DownloadState.downloaded).length;
}

/// Holds the singleton [DownloadManager] and exposes queue snapshots.
class DownloadManagerNotifier extends Notifier<DownloadQueueSnapshot>
    with WidgetsBindingObserver {
  late final DownloadManager manager;

  @override
  DownloadQueueSnapshot build() {
    manager = DownloadManager(
      keiyoushi: ref.watch(keiyoushiServiceProvider),
      extensionService: ref.watch(extensionServiceProvider),
      repositories: ref.watch(repositoriesProvider),
    );
    void onChange() {
      state = DownloadQueueSnapshot(
        queue: manager.queue,
        isRunning: manager.isRunning,
        isPaused: manager.isPaused,
      );
    }

    manager.addListener(onChange);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      manager.removeListener(onChange);
      manager.dispose();
    });
    return DownloadQueueSnapshot(
      queue: manager.queue,
      isRunning: manager.isRunning,
      isPaused: manager.isPaused,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(manager.scheduleBackgroundIfNeeded());
    }
  }

  Future<void> restore({bool autoStart = true}) =>
      manager.restore(autoStart: autoStart);

  Future<void> downloadChapters({
    required String sourceId,
    required String mangaUrl,
    required String mangaTitle,
    required List<Map<String, dynamic>> chapters,
    int? mangaId,
    String? mangaMemo,
    bool autoStart = true,
  }) =>
      manager.downloadChapters(
        sourceId: sourceId,
        mangaUrl: mangaUrl,
        mangaTitle: mangaTitle,
        chapters: chapters,
        mangaId: mangaId,
        mangaMemo: mangaMemo,
        autoStart: autoStart,
      );

  Future<void> startDownloads({bool retryErrors = true}) =>
      manager.startDownloads(retryErrors: retryErrors);
  Future<void> pauseDownloads() => manager.pauseDownloads();
  Future<void> clearQueue() => manager.clearQueue();
  Future<void> cancelQueuedDownloads(List<ChapterDownload> downloads) =>
      manager.cancelQueuedDownloads(downloads);
  Future<void> startDownloadNow(String chapterKey) =>
      manager.startDownloadNow(chapterKey);
}

final downloadManagerProvider =
    NotifierProvider<DownloadManagerNotifier, DownloadQueueSnapshot>(
      DownloadManagerNotifier.new,
    );

final extensionManagerProvider = Provider<ExtensionManager>(
  (ref) => ExtensionManager(
    ref.watch(repositoriesProvider),
    ref.watch(keiyoushiServiceProvider),
  ),
);

/// Number of installed extensions that have a newer version available
/// (`versionLast != version`). Refreshed by [extensionUpdateCountNotifier].
/// Watched by the Settings plugins row badge and the extensions screen.
class ExtensionUpdateCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> refresh() async {
    final mgr = ref.read(extensionManagerProvider);
    final installed = await mgr.listInstalled();
    state = installed.where((s) => s.isUpdateAvailable).length;
  }
}

final extensionUpdateCountProvider =
    NotifierProvider<ExtensionUpdateCountNotifier, int>(
      ExtensionUpdateCountNotifier.new,
    );

// ── Notifier providers ──────────────────────────────────────────────

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

final libraryUpdateProvider =
    NotifierProvider<LibraryUpdateNotifier, LibraryUpdateState>(
      LibraryUpdateNotifier.new,
    );

final libraryUpdateResultProvider =
    NotifierProvider<LibraryUpdateResultNotifier, LibraryUpdateReport?>(
      LibraryUpdateResultNotifier.new,
    );

final readerProvider = NotifierProvider<ReaderNotifier, ReaderState>(
  ReaderNotifier.new,
);

final snippetsProvider = NotifierProvider<SnippetsNotifier, SnippetsState>(
  SnippetsNotifier.new,
);

/// A monotonically increasing counter bumped whenever reading progress is
/// written (manga reader save, chapter mark-read, etc.). Screens that show
/// reading history/progress — which live inside the StatefulShellRoute
/// branches and therefore do not reliably receive RouteAware.didPopNext
/// from root-level detail routes like the reader — watch this and reload
/// when it changes. This is the real-time update channel for history.
class HistoryRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final historyRevisionProvider = NotifierProvider<HistoryRevisionNotifier, int>(
  HistoryRevisionNotifier.new,
);
