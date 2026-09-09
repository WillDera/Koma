import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/repositories/track_repository.dart';
import '../../core/services/trackers/anilist.dart';
import '../../core/services/trackers/manga_updates.dart';
import '../../core/services/trackers/myanimelist.dart';
import '../../core/services/trackers/track_chapter_use_case.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_section.dart';
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
  bool _muLoggedIn = false;
  String _malName = '';
  String _anilistName = '';
  String _muName = '';
  String _anilistClientId = '';
  String _anilistClientSecret = '';
  String _malClientId = '';

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
    final mu = await repos.tracks.getPreference(TrackIds.mangaUpdates);
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
      _muLoggedIn = mu?.oAuth?.isNotEmpty == true ||
          mu?.username?.isNotEmpty == true;
      _malName = mal?.displayName ?? mal?.username ?? '';
      _anilistName = al?.displayName ?? al?.username ?? '';
      _muName = mu?.displayName ?? mu?.username ?? '';
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
      // Defer dispose until after dialog + IME teardown (avoids
      // '_dependents.isEmpty' assertion when the keyboard hides).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.dispose();
      });
    }
    if (saved == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, saved.trim());
    await _reload();
  }

  Future<void> _loginMu() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool? ok;
    var user = '';
    var pass = '';
    try {
      ok = await showDialog<bool>(
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
                    'MangaUpdates login',
                    style: Theme.of(dialogCtx).textTheme.titleMedium?.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      user = userCtrl.text.trim();
      pass = passCtrl.text;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        userCtrl.dispose();
        passCtrl.dispose();
      });
    }
    if (ok != true || !mounted) return;
    try {
      await MangaUpdatesTracker(ref.read(repositoriesProvider)).login(user, pass);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in to MangaUpdates')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disconnected from $serviceName')),
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
                  await MyAnimeListTracker(ref.read(repositoriesProvider))
                      .login();
                  await _reload();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged in to MyAnimeList')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
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
                  await AnilistTracker(ref.read(repositoriesProvider)).login();
                  await _reload();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged in to AniList')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              },
            ),
            SettingsRow(
              leading: const TrackerBrandIcon(syncId: TrackIds.mangaUpdates),
              title: 'MangaUpdates',
              subtitle: _muLoggedIn
                  ? (_muName.isNotEmpty ? _muName : 'Logged in')
                  : 'Not logged in',
              onTap: () async {
                if (_muLoggedIn) {
                  await _confirmDisconnect(
                    syncId: TrackIds.mangaUpdates,
                    serviceName: 'MangaUpdates',
                    accountLabel: _muName,
                    onDisconnect: () => MangaUpdatesTracker(
                      ref.read(repositoriesProvider),
                    ).logout(),
                  );
                  return;
                }
                await _loginMu();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          title: 'OAuth clients',
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
        ),
      ],
    );
  }
}
