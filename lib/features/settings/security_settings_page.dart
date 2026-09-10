import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_lock_service.dart';
import '../../core/services/security_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/toast.dart';

/// Settings → Security hub page.
class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  var _togglingLock = false;

  void _toast(String message, {IconData icon = Icons.info_outline}) {
    if (!mounted) return;
    StashToast.show(context, message: message, icon: icon);
  }

  Future<void> _setAppLock(bool enable) async {
    if (_togglingLock) return;
    setState(() => _togglingLock = true);
    try {
      if (enable) {
        final status = await AppLockService.deviceAuthStatus();
        if (!mounted) return;

        if (!status.available) {
          // Emulators often have no PIN/fingerprint — still allow enabling
          // with an in-app confirm unlock fallback.
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final c = ctx.colors;
              return AlertDialog(
                backgroundColor: c.surface,
                title: Text(
                  'No device lock found',
                  style: TextStyle(color: c.textPrimary),
                ),
                content: Text(
                  '${status.detail}\n\n'
                  'Enable app lock anyway? Unlock will use an in-app '
                  'confirm button until a PIN/fingerprint is set up.',
                  style: TextStyle(color: c.textSecondary, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Enable anyway'),
                  ),
                ],
              );
            },
          );
          if (proceed != true || !mounted) return;
        } else {
          final result = await AppLockService.authenticate(
            reason: 'Enable app lock',
          );
          if (!mounted) return;
          if (!result.success) {
            _toast(
              result.errorMessage ?? 'Authentication cancelled',
              icon: Icons.lock_outline,
            );
            return;
          }
        }
      }
      await ref.read(appLockEnabledProvider.notifier).set(enable);
      if (enable) {
        ref.read(appUnlockedProvider.notifier).unlock();
        _toast('App lock on', icon: Icons.lock);
      } else {
        _toast('App lock off', icon: Icons.lock_open);
      }
    } finally {
      if (mounted) setState(() => _togglingLock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final incognito = ref.watch(incognitoProvider);
    final lockOn = ref.watch(appLockEnabledProvider);
    final secureMode = ref.watch(secureScreenProvider);

    return Column(
      children: [
        SettingsSection(
          title: 'Privacy',
          children: [
            SettingsRow(
              icon: Icons.visibility_off_outlined,
              title: 'Incognito mode',
              subtitle:
                  'Do not save reading history or chapter progress while on',
              trailing: Switch(
                value: incognito,
                activeThumbColor: c.accent,
                onChanged: (v) async {
                  await ref.read(incognitoProvider.notifier).set(v);
                  await AppLockService.applySecureScreen(
                    mode: ref.read(secureScreenProvider),
                    incognito: v,
                  );
                },
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'App lock',
          children: [
            SettingsRow(
              icon: Icons.lock_outline,
              title: 'Require unlock',
              subtitle: 'Biometric or device PIN when returning to Koma',
              trailing: Switch(
                value: lockOn,
                activeThumbColor: c.accent,
                onChanged: _togglingLock ? null : _setAppLock,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Secure screen',
          children: [
            SettingsRow(
              icon: Icons.screenshot_outlined,
              title: 'Hide from recents',
              subtitle: _secureLabel(secureMode),
              onTap: () => _pickSecureMode(context, secureMode),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            'Incognito skips history for manga and ebooks. Secure screen '
            'uses Android FLAG_SECURE (blocks screenshots and recent-task '
            'thumbnails). App lock needs a device PIN/biometric — emulators '
            'often have none until you set one.',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }

  static String _secureLabel(int mode) => switch (mode) {
        0 => 'Never',
        1 => 'When incognito',
        _ => 'Always',
      };

  Future<void> _pickSecureMode(BuildContext context, int current) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in const [
                (0, 'Never'),
                (1, 'When incognito'),
                (2, 'Always'),
              ])
                ListTile(
                  title: Text(e.$2, style: TextStyle(color: c.textPrimary)),
                  trailing: current == e.$1
                      ? Icon(Icons.check, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, e.$1),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await ref.read(secureScreenProvider.notifier).set(picked);
    await AppLockService.applySecureScreen(
      mode: picked,
      incognito: ref.read(incognitoProvider),
    );
  }
}
