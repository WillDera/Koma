import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/repositories/track_repository.dart';
import '../../core/services/trackers/anilist.dart';
import '../../core/services/trackers/myanimelist.dart';
import '../../core/services/trackers/track_chapter_use_case.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/toast.dart';
import '../../widgets/tracker_brand_icon.dart';

class TrackingSettingsPage extends ConsumerStatefulWidget {
  const TrackingSettingsPage({super.key});

  @override
  ConsumerState<TrackingSettingsPage> createState() =>
      _TrackingSettingsPageState();
}

class _TrackingSettingsPageState extends ConsumerState<TrackingSettingsPage>
    with WidgetsBindingObserver {
  bool _updateAfterReading = true;
  bool _malLoggedIn = false;
  bool _anilistLoggedIn = false;
  String _malName = '';
  String _anilistName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final prefs = await SharedPreferences.getInstance();
    final repos = ref.read(repositoriesProvider);
    final mal = await repos.tracks.getPreference(TrackIds.mal);
    final al = await repos.tracks.getPreference(TrackIds.anilist);
    if (!mounted) return;
    setState(() {
      _updateAfterReading =
          prefs.getBool(TrackChapterUseCase.updateAfterReadingKey) ?? true;
      _malLoggedIn = mal != null &&
          ((mal.oAuth?.isNotEmpty == true) ||
              (mal.username?.isNotEmpty == true));
      _anilistLoggedIn = al != null &&
          ((al.oAuth?.isNotEmpty == true) ||
              (al.username?.isNotEmpty == true));
      _malName = mal?.displayName ?? mal?.username ?? '';
      _anilistName = al?.displayName ?? al?.username ?? '';
    });
  }

  static String _friendlyAuthError(Object e, String service) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('cancel')) return 'Sign-in cancelled';
    if (raw.contains('client id') || raw.contains('not set')) {
      return 'Set $service client id in Settings → Advanced';
    }
    if (raw.contains('400') || raw.contains('invalid_grant')) {
      return "Couldn't connect to $service — try again";
    }
    return "Couldn't connect to $service";
  }

  Future<void> _confirmDisconnect({
    required int syncId,
    required String serviceName,
    required String accountLabel,
    required Future<void> Function() onDisconnect,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogCtx) {
        final c = dialogCtx.colors;
        return Dialog(
          backgroundColor: c.bgElevated,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.border, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TrackerBrandIcon(syncId: syncId, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        serviceName,
                        style: Theme.of(dialogCtx).textTheme.titleMedium
                            ?.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Connected as',
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accountLabel.isNotEmpty ? accountLabel : 'Logged in',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Disconnecting stops progress updates for this service. '
                  'Existing links on manga titles stay until you remove them.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: Text(
                        'Close',
                        style: TextStyle(color: c.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC44C4C),
                      ),
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await onDisconnect();
    await _reload();
    if (!mounted) return;
    StashToast.show(
      context,
      message: 'Disconnected from $serviceName',
      icon: Icons.link_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        SettingsSection(
          title: 'Progress',
          children: [
            SettingsRow(
              icon: Icons.sync_rounded,
              title: 'Update progress after reading',
              subtitle: 'Push chapter progress to linked trackers',
              trailing: Switch(
                value: _updateAfterReading,
                activeThumbColor: c.accent,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(
                    TrackChapterUseCase.updateAfterReadingKey,
                    v,
                  );
                  setState(() => _updateAfterReading = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'Services',
          children: [
            SettingsRow(
              leading: const TrackerBrandIcon(syncId: TrackIds.mal),
              title: 'MyAnimeList',
              subtitle: _malLoggedIn
                  ? (_malName.isNotEmpty ? _malName : 'Logged in')
                  : 'Not logged in',
              onTap: () async {
                if (_malLoggedIn) {
                  await _confirmDisconnect(
                    syncId: TrackIds.mal,
                    serviceName: 'MyAnimeList',
                    accountLabel: _malName,
                    onDisconnect: () => MyAnimeListTracker(
                      ref.read(repositoriesProvider),
                    ).logout(),
                  );
                  return;
                }
                try {
                  // Resume from a stuck Custom Tab can leave UI stale while
                  // tokens are already saved — don't start a second OAuth.
                  await _reload();
                  if (!mounted) return;
                  if (_malLoggedIn) return;
                  await MyAnimeListTracker(ref.read(repositoriesProvider))
                      .login();
                  await _reload();
                  if (!mounted) return;
                  StashToast.show(
                    context,
                    message: 'Logged in to MyAnimeList',
                    icon: Icons.check,
                  );
                } catch (e) {
                  await _reload();
                  if (!mounted) return;
                  if (_malLoggedIn) {
                    StashToast.show(
                      context,
                      message: 'Logged in to MyAnimeList',
                      icon: Icons.check,
                    );
                    return;
                  }
                  StashToast.show(
                    context,
                    message: _friendlyAuthError(e, 'MyAnimeList'),
                    icon: Icons.error_outline,
                  );
                }
              },
            ),
            SettingsRow(
              leading: const TrackerBrandIcon(syncId: TrackIds.anilist),
              title: 'AniList',
              subtitle: _anilistLoggedIn
                  ? (_anilistName.isNotEmpty ? _anilistName : 'Logged in')
                  : 'Not logged in',
              onTap: () async {
                if (_anilistLoggedIn) {
                  await _confirmDisconnect(
                    syncId: TrackIds.anilist,
                    serviceName: 'AniList',
                    accountLabel: _anilistName,
                    onDisconnect: () => AnilistTracker(
                      ref.read(repositoriesProvider),
                    ).logout(),
                  );
                  return;
                }
                try {
                  await _reload();
                  if (!mounted) return;
                  if (_anilistLoggedIn) return;
                  await AnilistTracker(ref.read(repositoriesProvider)).login();
                  await _reload();
                  if (!mounted) return;
                  StashToast.show(
                    context,
                    message: 'Logged in to AniList',
                    icon: Icons.check,
                  );
                } catch (e) {
                  await _reload();
                  if (!mounted) return;
                  if (_anilistLoggedIn) {
                    StashToast.show(
                      context,
                      message: 'Logged in to AniList',
                      icon: Icons.check,
                    );
                    return;
                  }
                  StashToast.show(
                    context,
                    message: _friendlyAuthError(e, 'AniList'),
                    icon: Icons.error_outline,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// OAuth client ids / secrets — lives under Settings → Advanced.
class TrackingOAuthClientsSection extends StatefulWidget {
  const TrackingOAuthClientsSection({super.key});

  @override
  State<TrackingOAuthClientsSection> createState() =>
      _TrackingOAuthClientsSectionState();
}

class _TrackingOAuthClientsSectionState
    extends State<TrackingOAuthClientsSection> {
  String _anilistClientId = '';
  String _anilistClientSecret = '';
  String _malClientId = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _anilistClientId = prefs.getString(AnilistTracker.clientIdKey) ?? '';
      _anilistClientSecret =
          prefs.getString(AnilistTracker.clientSecretKey) ?? '';
      _malClientId = prefs.getString(MyAnimeListTracker.clientIdKey) ?? '';
    });
  }

  Future<void> _editPref(String key, String title, String current) async {
    final ctrl = TextEditingController(text: current);
    String? saved;
    try {
      saved = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (dialogCtx) {
          final c = dialogCtx.colors;
          return Dialog(
            backgroundColor: c.bgElevated,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: c.border, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(dialogCtx).textTheme.titleMedium?.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: title,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (v) => Navigator.of(dialogCtx).pop(v.trim()),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(dialogCtx).pop(ctrl.text.trim()),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.dispose();
      });
    }
    if (saved == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, saved.trim());
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'OAuth clients',
      footer:
          'Register redirect URLs with each service, then paste client ids here. '
          'Sign in from Settings → Tracking.',
      children: [
        SettingsRow(
          icon: Icons.info_outline,
          title: 'Redirect URLs',
          subtitle:
              'AniList: ${AnilistTracker.redirectUri}\n'
              'MAL: ${MyAnimeListTracker.redirectUri}',
        ),
        SettingsRow(
          icon: Icons.key_outlined,
          title: 'AniList client id',
          subtitle: _anilistClientId.isEmpty ? 'Not set' : '•••• set',
          onTap: () => _editPref(
            AnilistTracker.clientIdKey,
            'AniList client id',
            _anilistClientId,
          ),
        ),
        SettingsRow(
          icon: Icons.lock_outline,
          title: 'AniList client secret',
          subtitle: _anilistClientSecret.isEmpty ? 'Not set' : '•••• set',
          onTap: () => _editPref(
            AnilistTracker.clientSecretKey,
            'AniList client secret',
            _anilistClientSecret,
          ),
        ),
        SettingsRow(
          icon: Icons.key_outlined,
          title: 'MyAnimeList client id',
          subtitle: _malClientId.isEmpty ? 'Not set' : '•••• set',
          onTap: () => _editPref(
            MyAnimeListTracker.clientIdKey,
            'MyAnimeList client id',
            _malClientId,
          ),
        ),
      ],
    );
  }
}
