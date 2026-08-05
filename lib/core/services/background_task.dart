import 'package:workmanager/workmanager.dart';

import '../isar/isar.dart';
import '../repositories/repositories.dart';
import 'extension_manager.dart';
import 'keiyoushi_service.dart';
import 'library_update_service.dart';
import 'notification_service.dart';

/// Unique name for the periodic library-poll task. Used both to register and
/// to cancel the WorkManager job (mangayomi's LibUpdatesAlarm parity).
const String kLibraryPollTaskName = 'com.koma.library_update';

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
  }
}
