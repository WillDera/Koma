import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_lock_service.dart';
import '../core/services/security_prefs.dart';
import '../theme/app_theme.dart';

/// Full-screen lock gate shown when [appUnlockedProvider] is false.
class AppLockOverlay extends ConsumerStatefulWidget {
  const AppLockOverlay({super.key});

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay> {
  var _busy = false;
  String? _error;

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppLockService.authenticate();
    if (!mounted) return;
    if (ok) {
      ref.read(appUnlockedProvider.notifier).unlock();
    } else {
      setState(() => _error = 'Authentication failed');
    }
    setState(() => _busy = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 48, color: c.accent),
                const SizedBox(height: 16),
                Text(
                  'Koma is locked',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to continue',
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: c.accent, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(_busy ? 'Waiting…' : 'Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
