import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_lock_service.dart';
import '../../core/services/security_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section.dart';

/// Settings → Security hub page.
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onChanged: (v) async {
                  if (v) {
                    final can = await AppLockService.canAuthenticate();
                    if (!can) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Set up a screen lock or biometrics first',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    final ok = await AppLockService.authenticate(
                      reason: 'Enable app lock',
                    );
                    if (!ok) return;
                  }
                  await ref.read(appLockEnabledProvider.notifier).set(v);
                  if (v) {
                    ref.read(appUnlockedProvider.notifier).unlock();
                  }
                },
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
              onTap: () => _pickSecureMode(context, ref, secureMode),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            'Incognito skips history for manga and ebooks. Secure screen '
            'uses Android FLAG_SECURE (blocks screenshots and recent-task '
            'thumbnails).',
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

  Future<void> _pickSecureMode(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
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
    if (picked == null) return;
    await ref.read(secureScreenProvider.notifier).set(picked);
    await AppLockService.applySecureScreen(
      mode: picked,
      incognito: ref.read(incognitoProvider),
    );
  }
}
