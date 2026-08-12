import 'package:flutter/material.dart';

import '../core/services/app_update/app_update_checker.dart';
import '../core/services/app_update/get_application_release.dart';
import 'new_update_sheet.dart';

/// Runs Mihon's startup [CheckForUpdates] once the shell is mounted.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _check();
  }

  Future<void> _check() async {
    if (!AppUpdateChecker.updaterEnabled) return;
    try {
      final result = await AppUpdateChecker().checkForUpdate();
      if (!mounted) return;
      if (result is NewAppUpdate) {
        await NewUpdateSheet.show(context, result.release);
      }
    } catch (_) {
      // Network / GitHub failures are silent on launch (Mihon parity).
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
