import 'package:workmanager/workmanager.dart';

import '../isar/isar.dart';
import '../repositories/repositories.dart';
import 'download/chapter_download.dart';
import 'download/download_manager.dart';
import 'download/download_store.dart';
import 'extension_manager.dart';
import 'keiyoushi_service.dart';
import 'library_update_auto_download.dart';
import 'library_update_prefs.dart';
import 'library_update_service.dart';
import 'notification_service.dart';

/// Unique name for the periodic library-poll task. Used both to register and
/// to cancel the WorkManager job (mangayomi's LibUpdatesAlarm parity).
const String kLibraryPollTaskName = 'com.koma.library_update';

/// Unique name for the one-off chapter download drain (Mihon DownloadJob).
const String kDownloadTaskName = DownloadManager.downloadTaskName;

/// WorkManager entry point. Runs in a background isolate on a fresh
/// FlutterEngine, so it cannot rely on the MainActivity MethodChannel — the
/// DalvikServer port is discovered through DalvikRuntimeManager's persisted
/// SharedPreferences value (KeiyoushiService.init fallback).
///
/// Must be a top-level function (workmanager requirement).
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == kLibraryPollTaskName) {
        await _pollLibraryAndNotify();
      } else if (task == kDownloadTaskName) {
        await _drainDownloadQueue();
      }
      return true;
    } catch (_) {
      // Returning false asks the OS to retry the task later. Keep it silent
      // here so a single bad poll (e.g. server not up) doesn't spam the log.
      return false;
    }
  });
}

Future<void> _pollLibraryAndNotify() async {
  final isar = await openIsar();
  final repos = Repositories(isar);
  final keiyoushi = KeiyoushiService();
  final extensionManager = ExtensionManager(repos, keiyoushi);
  final service = LibraryUpdateService(
    repos,
    keiyoushi,
    extensionManager: extensionManager,
  );
  final report = await service.checkForNewChapters();
  if (report.totalNew > 0) {
    await NotificationService.instance.init();
    await NotificationService.instance.notifyNewChapters(report);

    // Auto-queue newly discovered chapters (Mihon LibraryUpdateJob parity).
    if (await LibraryUpdatePrefs.isDownloadNewEnabled()) {
      await keiyoushi.init();
      final mgr = DownloadManager(keiyoushi: keiyoushi, repositories: repos);
      await mgr.restore(autoStart: false);
      await enqueueNewChaptersFromUpdate(
        manager: mgr,
        report: report,
        downloadNewOverride: true,
        autoStart: false,
      );
      if (mgr.queue.any((d) => d.status == DownloadState.queue)) {
        await mgr.scheduleBackgroundIfNeeded();
      }
    }
  }
}

/// Background drain of the persisted download queue when the UI isolate is
/// not the active runner (app backgrounded / killed mid-queue).
Future<void> _drainDownloadQueue() async {
  final store = DownloadStore();
  if (await store.isPaused()) return;
  if (await store.runner() == 'ui') return;

  final isar = await openIsar();
  final repos = Repositories(isar);
  final keiyoushi = KeiyoushiService();
  await keiyoushi.init();
  final mgr = DownloadManager(keiyoushi: keiyoushi, repositories: repos);
  await mgr.restore(autoStart: false);
  if (mgr.queue.isEmpty || await store.isPaused()) return;

  // Prefer pending queue items only — ERROR stays until explicit retry.
  // Treating ERROR as work re-queued races with the UI and spawned a second
  // FlutterEngine (looked like a crash).
  final needsWork = mgr.queue.any((d) => d.status == DownloadState.queue);
  if (!needsWork) return;

  await mgr.runUntilIdle(runner: 'wm');
}
