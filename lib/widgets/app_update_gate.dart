import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/services/app_update/app_update_checker.dart';
import '../core/services/app_update/app_update_manager.dart';
import '../core/services/app_update/get_application_release.dart';
import '../core/services/notification_service.dart';
import 'new_update_sheet.dart';

/// Runs Mihon's startup [CheckForUpdates] once the shell is mounted and
/// wires notification taps for background update downloads.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onNotificationTap = _onNotificationTap;
  }

  @override
  void dispose() {
    if (NotificationService.instance.onNotificationTap == _onNotificationTap) {
      NotificationService.instance.onNotificationTap = null;
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _check();
  }

  void _onNotificationTap(String? payload) {
    if (payload != NotificationService.payloadAppUpdateReady) return;
    final update = ref.read(appUpdateProvider);
    final release = update.release;
    if (release == null || update.stage != AppUpdateStage.downloaded) return;
    if (!mounted) return;
    NewUpdateSheet.show(context, release);
  }

  Future<void> _check() async {
    if (!AppUpdateChecker.updaterEnabled) return;
    try {
      final notifier = ref.read(appUpdateProvider.notifier);
      final result = await notifier.checkForUpdate();
      if (!mounted) return;
      if (result is NewAppUpdate) {
        notifier.offerUpdate(result.release);
        await NewUpdateSheet.show(context, result.release);
      } else {
        // Drop a leftover APK from an update that is already installed.
        notifier.clear();
      }
    } catch (_) {
      // Network / GitHub failures are silent on launch (Mihon parity).
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
