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
  var _useConfirmFallback = false;

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    if (_useConfirmFallback) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = ctx.colors;
          return AlertDialog(
            backgroundColor: c.surface,
            title: Text('Unlock Koma', style: TextStyle(color: c.textPrimary)),
            content: Text(
              'No device PIN/biometric is available. Confirm to unlock.',
              style: TextStyle(color: c.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      if (ok == true) {
        ref.read(appUnlockedProvider.notifier).unlock();
      }
      setState(() => _busy = false);
      return;
    }

    final result = await AppLockService.authenticate();
    if (!mounted) return;
    if (result.success) {
      ref.read(appUnlockedProvider.notifier).unlock();
    } else if (result.deviceAuthUnavailable) {
      setState(() {
        _useConfirmFallback = true;
        _error = result.errorMessage;
      });
    } else {
      setState(() => _error = result.errorMessage ?? 'Authentication failed');
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
                  _useConfirmFallback
                      ? 'Tap unlock to continue'
                      : 'Authenticate to continue',
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.accent, fontSize: 13, height: 1.35),
                  ),
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
                      : Icon(
                          _useConfirmFallback
                              ? Icons.lock_open
                              : Icons.fingerprint,
                        ),
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
