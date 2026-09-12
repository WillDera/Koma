import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/extension_repo.dart';
import '../../core/models/extension_source.dart';
import '../../core/services/extension_icon_cache.dart';
import '../../core/services/extension_manager.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import '../../core/utils/language.dart';
import 'package:go_router/go_router.dart';

import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/aethelgard_fab.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/screen_chrome.dart';
import 'extension_detail_screen.dart';
import 'extensions_catalog_provider.dart';
import 'source_browse_screen.dart';

const _keiyoushiDefaultRepoUrl =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb';
const _keiyoushiDefaultRepoName = 'Keiyoushi (official)';

String _extractPkgFromApkPath(String apkPath) => extractPkgFromApkPath(apkPath);

Set<String> _installedPkgs(List<ExtensionSource> installed) =>
    installedPkgsOf(installed);

Route<T> _scaleFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        scaleFadePageTransition(animation: animation, child: child),
  );
}

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key, this.initialTabIndex = 0});

  /// 0 = Loaded, 1 = Available, 2 = Repos.
  final int initialTabIndex;

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Available-tab local filters (independent of Settings NSFW prefs).
  /// When true, only NSFW rows are listed; when false, NSFW is hidden.
  bool _availShowOnlyNsfw = false;
  String _availLang = 'all';
  final Set<String> _availTypes = {
    SourceCodeLanguage.mihon,
    SourceCodeLanguage.js,
    SourceCodeLanguage.dart,
  };

  ExtensionsCatalogNotifier get _catalog =>
      ref.read(extensionsCatalogProvider.notifier);

  ExtensionManager get _mgr => _catalog.manager;

  List<ExtensionRepo> get _repos => ref.watch(extensionsCatalogProvider).repos;
  List<ExtensionSource> get _installed =>
      ref.watch(extensionsCatalogProvider).installed;
  Map<int, List<ExtensionIndexEntry>> get _fullIndexCache =>
      ref.watch(extensionsCatalogProvider).fullIndexCache;
  Map<int, List<ExtensionIndexEntry>> get _indexCache =>
      ref.watch(extensionsCatalogProvider).indexCache;
  Set<int> get _loadingIndex =>
      ref.watch(extensionsCatalogProvider).loadingIndex;
  String? get _error => ref.watch(extensionsCatalogProvider).error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 2);
    _tabs = TabController(length: 3, vsync: this, initialIndex: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_catalog.ensureBootstrapped());
      if (initial == 1) unawaited(_fetchAllIndexes());
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _catalog.refreshInstalled();

  Future<void> _fetchIndex(ExtensionRepo repo) => _catalog.fetchIndex(repo);

  Future<void> _fetchAllIndexes() => _catalog.fetchAllIndexes();

  Future<bool> _confirmTrust(UntrustedExtensionException e) async {
    final c = context.colors;
    final action = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      useRootNavigator: false,
      builder: (ctx) => StashDialog(
        title: 'Untrusted extension',
        content:
            '${e.info.packageName} is not signed by a known repository. '
            'Installing it may put your device and data at risk.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Uninstall', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Trust', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
    return action == true;
  }

  Future<void> _ensureRepoSeeded() async {
    if (_repos.isNotEmpty) return;
    await _mgr.addRepo(
      name: _keiyoushiDefaultRepoName,
      url: _keiyoushiDefaultRepoUrl,
      kind: ExtensionRepoKind.mihon,
    );
    await _refresh();
  }

  Future<void> _addRepoDialog() async {
    final nameCtl = TextEditingController();
    final urlCtl = TextEditingController();
    var kind = ExtensionRepoKind.mihon;
    final ok = await StashDialog.show<bool>(
      context,
      title: 'Add repo',
      contentWidget: StatefulBuilder(
        builder: (ctx, setLocal) {
          final c = ctx.colors;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My sources',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtl,
                decoration: const InputDecoration(
                  labelText: 'Index URL (.pb or JSON)',
                  hintText: _keiyoushiDefaultRepoUrl,
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              Text(
                'Ecosystem',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Mihon (APK)'),
                    selected: kind == ExtensionRepoKind.mihon,
                    onSelected: (_) =>
                        setLocal(() => kind = ExtensionRepoKind.mihon),
                  ),
                  ChoiceChip(
                    label: const Text('JavaScript'),
                    selected: kind == ExtensionRepoKind.javascript,
                    onSelected: (_) =>
                        setLocal(() => kind = ExtensionRepoKind.javascript),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Leave blank URL schema defaults — kind is also auto-detected from the index when unsure.',
                style: TextStyle(color: c.textTertiary, fontSize: 11),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (nameCtl.text.trim().isEmpty || urlCtl.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(true);
          },
          child: const Text('Add'),
        ),
      ],
    );
    if (ok == true) {
      await _mgr.addRepo(
        name: nameCtl.text.trim(),
        url: urlCtl.text.trim(),
        kind: kind,
      );
      await _refresh();
    }
  }

  Future<void> _removeRepo(ExtensionRepo repo) async {
    await _catalog.removeRepo(repo.id);
  }

  Future<void> _install(ExtensionIndexEntry entry, ExtensionRepo repo) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Loading ${entry.name}...')));
    try {
      final src = await _mgr.install(entry, repoUrl: repo.url);
      messenger.showSnackBar(SnackBar(content: Text('Loaded ${src.name}')));
      await _refresh();
      await _fetchIndex(repo);
    } on UnsupportedExtensionLanguageException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unsupported extension language'
            '${e.name != null && e.name!.isNotEmpty ? ' (${e.name})' : ''}',
          ),
        ),
      );
    } on UntrustedExtensionException catch (e) {
      // JS/Dart installs never go through APK trust — skip the dialog path.
      if (entry.isJs || entry.isDart) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Load failed for ${entry.isDart ? 'Dart' : 'JS'} source ${entry.name}',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final trust = await _confirmTrust(e);
      if (!mounted) return;
      if (trust) {
        try {
          final src = await _mgr.trustAndInstall(
            e.info,
            entry,
            repoUrl: repo.url,
          );
          messenger.showSnackBar(SnackBar(content: Text('Loaded ${src.name}')));
          await _refresh();
          await _fetchIndex(repo);
        } catch (err) {
          messenger.showSnackBar(SnackBar(content: Text('Load failed: $err')));
        }
      } else {
        await _mgr.discardUntrustedApk(entry);
        messenger.showSnackBar(
          SnackBar(content: Text('Discarded ${entry.name}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
  }

  Future<void> _trustExisting(ExtensionSource src) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _mgr.trustExistingPackage(src);
      messenger.showSnackBar(SnackBar(content: Text('Trusted ${src.name}')));
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Trust failed: $e')));
    }
  }

  Future<void> _uninstall(ExtensionSource src) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _mgr.uninstall(src);
      messenger.showSnackBar(SnackBar(content: Text('Unloaded ${src.name}')));
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Unload failed: $e')));
    }
  }

  /// Find the index entry + repo for an installed source so it can be
  /// re-downloaded at a newer version.
  ///
  /// Prefer [ExtensionSource.versionLast] (badge target) over the first
  /// cache hit — stale `_fullIndexCache` rows often still carry the installed
  /// version after startup already wrote a newer `versionLast`.
  ({ExtensionIndexEntry entry, ExtensionRepo repo})? _resolveUpdate(
    ExtensionSource src,
  ) {
    final pkg = _extractPkgFromApkPath(src.apkPath);
    final candidates = <({ExtensionIndexEntry entry, ExtensionRepo repo})>[];

    for (final repo in _repos) {
      final entries = _fullIndexCache[repo.id];
      if (entries == null) continue;
      for (final e in entries) {
        var matched = false;
        if (e.className != null &&
            e.className!.isNotEmpty &&
            e.className == src.className) {
          matched = true;
        } else if (pkg.isNotEmpty && e.pkg == pkg) {
          matched = true;
        } else if ((src.isJs || src.isDart) &&
            (e.isJs || e.isDart) &&
            (e.pkg == src.sourceId ||
                e.pkg == src.id ||
                (src.sourceCodeUrl != null &&
                    src.sourceCodeUrl!.isNotEmpty &&
                    e.sourceCodeUrl == src.sourceCodeUrl))) {
          matched = true;
        }
        if (matched) candidates.add((entry: e, repo: repo));
      }
    }
    if (candidates.isEmpty) return null;

    final target = src.versionLast;
    if (target != null &&
        target.isNotEmpty &&
        compareVersions(src.version, target) < 0) {
      final exact = candidates.where((c) => c.entry.version == target).toList();
      if (exact.isNotEmpty) {
        // Prefer the source's own repo when multiple indexes share a pkg id.
        final sameRepo = exact.where((c) => c.repo.url == src.repoUrl).toList();
        return (sameRepo.isNotEmpty ? sameRepo : exact).first;
      }
    }

    // Newest entry that is actually newer than the installed version.
    // Prefer candidates from the extension's install repo.
    final ordered = [...candidates]
      ..sort((a, b) {
        final byVer = compareVersions(b.entry.version, a.entry.version);
        if (byVer != 0) return byVer;
        final aSame = a.repo.url == src.repoUrl ? 0 : 1;
        final bSame = b.repo.url == src.repoUrl ? 0 : 1;
        return aSame.compareTo(bSame);
      });
    for (final c in ordered) {
      if (compareVersions(src.version, c.entry.version) < 0) return c;
    }
    return null;
  }

  Future<void> _update(ExtensionSource src) async {
    final messenger = ScaffoldMessenger.of(context);

    // Mangayomi parity: update always re-fetches the index (reFresh: true)
    // before resolving — in-memory cache can still list the old version while
    // `versionLast` already points at the newer one from app-start checks.
    final reposToFetch = <ExtensionRepo>[];
    if (src.repoUrl != null && src.repoUrl!.isNotEmpty) {
      final owned = _repos.where((r) => r.url == src.repoUrl).firstOrNull;
      if (owned != null) reposToFetch.add(owned);
    }
    if (reposToFetch.isEmpty) {
      final kind = (src.isJs || src.isDart)
          ? ExtensionRepoKind.javascript
          : ExtensionRepoKind.mihon;
      reposToFetch.addAll(_repos.where((r) => r.enabled && r.kind == kind));
    }
    if (reposToFetch.isEmpty) {
      reposToFetch.addAll(_repos.where((r) => r.enabled));
    }
    for (final repo in reposToFetch) {
      if (!mounted) return;
      await _fetchIndex(repo);
    }

    final resolved = _resolveUpdate(src);
    if (resolved == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            src.versionLast != null &&
                    src.versionLast!.isNotEmpty &&
                    src.versionLast != src.version
                ? 'Could not find v${src.versionLast} for ${src.name} in the repo index'
                : 'No update info for ${src.name} — fetch the repo index first',
          ),
        ),
      );
      return;
    }
    if (compareVersions(src.version, resolved.entry.version) >= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${src.name} is already at v${src.version} (index has v${resolved.entry.version})',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text('Updating ${src.name}…')));
    try {
      await _mgr.updateSource(src, resolved.entry, resolved.repo.url);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Updated ${src.name} to v${resolved.entry.version}'),
        ),
      );
      await _refresh();
    } on UnsupportedExtensionLanguageException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unsupported extension language'
            '${e.name != null && e.name!.isNotEmpty ? ' (${e.name})' : ''}',
          ),
        ),
      );
    } on UntrustedExtensionException catch (e) {
      if (src.isJs ||
          src.isDart ||
          resolved.entry.isJs ||
          resolved.entry.isDart) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Update failed for ${src.isDart || resolved.entry.isDart ? 'Dart' : 'JS'} '
              'source ${src.name}',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final trust = await _confirmTrust(e);
      if (!mounted) return;
      if (trust) {
        try {
          await _mgr.trustAndUpdate(e.info, src, resolved.entry);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Updated ${src.name} to v${resolved.entry.version}',
              ),
            ),
          );
          await _refresh();
        } catch (err) {
          messenger.showSnackBar(
            SnackBar(content: Text('Update failed: $err')),
          );
        }
      } else {
        await _mgr.discardUntrustedApk(resolved.entry);
        await _mgr.uninstall(src);
        messenger.showSnackBar(
          SnackBar(content: Text('Discarded ${src.name}')),
        );
        await _refresh();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _updateAll() async {
    final updatable = _installed
        .where((s) => s.isActive && s.isUpdateAvailable)
        .toList();
    for (final src in updatable) {
      if (!mounted) return;
      await _update(src);
    }
  }

  void _openAvailableFilter() {
    final theme = ref.read(themeProvider);
    var showNsfw = theme.showNsfwExtensions;
    var showObsolete = theme.showObsoleteExtensions;
    var showOnlyNsfw = showNsfw && _availShowOnlyNsfw;
    var lang = _availLang;
    final types = Set<String>.from(_availTypes);
    StashSheet.show<void>(
      context,
      title: 'Filters and Controls',
      initialChildSize: 0.65,
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = ctx.colors;
          Widget typeChip(String value, String label) {
            final selected = types.contains(value);
            return FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (v) {
                setSheet(() {
                  if (v) {
                    types.add(value);
                  } else if (types.length > 1) {
                    types.remove(value);
                  }
                });
              },
            );
          }

          Widget kenjiToggle({
            required String title,
            required String subtitle,
            required bool value,
            required ValueChanged<bool>? onChanged,
          }) {
            final enabled = onChanged != null;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: enabled ? c.textPrimary : c.textTertiary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              kenjiToggle(
                title: 'Show NSFW extensions',
                subtitle: showNsfw
                    ? 'NSFW extensions are listed'
                    : 'NSFW extensions are hidden',
                value: showNsfw,
                onChanged: (v) => setSheet(() {
                  showNsfw = v;
                  if (!v) showOnlyNsfw = false;
                }),
              ),
              kenjiToggle(
                title: 'Show only NSFW',
                subtitle: !showNsfw
                    ? 'Turn on Show NSFW extensions first'
                    : showOnlyNsfw
                    ? 'Only NSFW extensions listed'
                    : 'NSFW and non-NSFW extensions listed',
                value: showOnlyNsfw,
                onChanged: showNsfw
                    ? (v) => setSheet(() => showOnlyNsfw = v)
                    : null,
              ),
              kenjiToggle(
                title: 'Show obsolete extensions',
                subtitle: showObsolete
                    ? 'Outdated extensions are listed'
                    : 'Outdated extensions are hidden',
                value: showObsolete,
                onChanged: (v) => setSheet(() => showObsolete = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Language',
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in _allowedLanguages)
                    ChoiceChip(
                      label: Text(
                        code == 'all' ? 'All' : completeLanguageName(code),
                      ),
                      selected: lang == code,
                      onSelected: (_) => setSheet(() => lang = code),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Type',
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  typeChip(SourceCodeLanguage.mihon, 'Mihon'),
                  typeChip(SourceCodeLanguage.dart, 'Dart'),
                  typeChip(SourceCodeLanguage.js, 'JS'),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final tn = ref.read(themeProvider.notifier);
                    await tn.setShowNsfwExtensions(showNsfw);
                    await tn.setShowObsoleteExtensions(showObsolete);
                    if (!mounted) return;
                    setState(() {
                      _availShowOnlyNsfw = showNsfw && showOnlyNsfw;
                      _availLang = lang;
                      _availTypes
                        ..clear()
                        ..addAll(types);
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        title: Text('Extensions', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Batch migrate library titles',
            icon: Icon(Icons.swap_horiz, color: c.textPrimary),
            onPressed: () => context.pushNamed(Routes.migrateBatch),
          ),
          IconButton(
            icon: Icon(Icons.cloud_download_outlined, color: c.textPrimary),
            onPressed: _fetchAllIndexes,
          ),
          IconButton(
            tooltip: 'Filters and controls',
            icon: Icon(Icons.filter_list_rounded, color: c.textPrimary),
            onPressed: _openAvailableFilter,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: c.accent,
          labelColor: c.accent,
          unselectedLabelColor: c.textSecondary,
          tabs: const [
            Tab(text: 'Loaded'),
            Tab(text: 'Available'),
            Tab(text: 'Repos'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: c.accentMuted,
              child: Text(
                _error!,
                style: TextStyle(color: c.accent, fontSize: 12),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _InstalledTab(
                  installed: _installed,
                  repos: _repos,
                  onUninstall: _uninstall,
                  onUpdate: _update,
                  onUpdateAll: _updateAll,
                  onTrust: _trustExisting,
                  onBrowseAvailable: () => _tabs.animateTo(1),
                  onBrowse: (src) => Navigator.push(
                    context,
                    _scaleFadeRoute(
                      SourceBrowseScreen(
                        sourceId: src.sourceId,
                        sourceName: src.name,
                        baseUrl: src.baseUrl,
                      ),
                    ),
                  ),
                ),
                _AvailableTab(
                  repos: _repos,
                  indexCache: _indexCache,
                  loading: _loadingIndex,
                  installed: _installed,
                  showNsfw: theme.showNsfwExtensions,
                  showOnlyNsfw: theme.showNsfwExtensions && _availShowOnlyNsfw,
                  langFilter: _availLang,
                  typeFilters: _availTypes,
                  showObsolete: theme.showObsoleteExtensions,
                  onFetch: _fetchIndex,
                  onFetchAll: _fetchAllIndexes,
                  onInstall: _install,
                  onSeed: _ensureRepoSeeded,
                ),
                _ReposTab(
                  repos: _repos,
                  onAdd: _addRepoDialog,
                  onRemove: _removeRepo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Installed tab ──────────────────────────────────────────────────────
// ─── Shared Extensions hub chrome (Loaded / Available / Repos) ─────────

BoxDecoration _hubCardDecoration(KomaColors c, {bool accent = false}) {
  return BoxDecoration(
    color: accent ? c.accentMuted.withValues(alpha: 0.35) : c.surface,
    borderRadius: AppSpacing.brMd,
    border: Border.all(
      color: accent ? c.accent.withValues(alpha: 0.6) : c.border,
    ),
  );
}

/// Static group label — always visible, never accordion/chevron.
class _HubSectionLabel extends StatelessWidget {
  final String label;
  final Color? color;
  final String? trailing;

  const _HubSectionLabel(this.label, {this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color ?? c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _InstalledTab extends StatelessWidget {
  final List<ExtensionSource> installed;
  final List<ExtensionRepo> repos;
  final void Function(ExtensionSource) onUninstall;
  final void Function(ExtensionSource) onUpdate;
  final VoidCallback onUpdateAll;
  final void Function(ExtensionSource) onTrust;
  final VoidCallback onBrowseAvailable;
  final void Function(ExtensionSource) onBrowse;

  const _InstalledTab({
    required this.installed,
    required this.repos,
    required this.onUninstall,
    required this.onUpdate,
    required this.onUpdateAll,
    required this.onTrust,
    required this.onBrowseAvailable,
    required this.onBrowse,
  });

  String _repoLabel(ExtensionSource src) {
    final url = src.repoUrl;
    if (url != null && url.isNotEmpty) {
      for (final r in repos) {
        if (r.url == url) return r.name;
      }
    }
    return src.isDart ? 'Dart' : (src.isJs ? 'JavaScript' : 'Mihon');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (installed.isEmpty) {
      return EmptyState(
        icon: AppIcons.download,
        emoji: '🧩',
        title: 'No extensions installed',
        subtitle: 'Browse available extensions to add your first source.',
        primaryActionLabel: 'Browse available',
        onPrimaryAction: onBrowseAvailable,
        pillPrimary: true,
      );
    }

    // One tile per APK — Untrusted first, then active grouped by language.
    final byApk = <String, ExtensionSource>{};
    for (final s in installed) {
      final key = s.apkPath.isNotEmpty ? s.apkPath : s.sourceId;
      byApk.putIfAbsent(key, () => s);
    }
    final unique = byApk.values.toList();
    // Only true Untrusted (inactive + signing metadata). Do not list every
    // inactive APK — repo-signed inactives would all activate on the next
    // reconcileTrust after trusting a single sideload.
    final untrusted = unique.where((s) => s.isUntrusted).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final active = unique.where((s) => s.isActive).toList();
    final updates = active.where((s) => s.isUpdateAvailable).toList();

    final byLang = <String, List<ExtensionSource>>{};
    for (final s in active) {
      final key = s.lang.trim().isEmpty ? 'other' : s.lang.toLowerCase();
      byLang.putIfAbsent(key, () => []).add(s);
    }
    for (final list in byLang.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final langKeys = byLang.keys.toList()
      ..sort((a, b) {
        if (a == 'en') return -1;
        if (b == 'en') return 1;
        return completeLanguageName(a).compareTo(completeLanguageName(b));
      });

    final children = <Widget>[];
    if (updates.isNotEmpty) {
      children.add(
        _UpdateAllBanner(count: updates.length, onUpdateAll: onUpdateAll),
      );
    }
    if (untrusted.isNotEmpty) {
      children.add(_HubSectionLabel('Untrusted', color: c.accent));
      for (final src in untrusted) {
        children.add(
          _UntrustedTile(
            src: src,
            onTrust: () => onTrust(src),
            onUninstall: () => onUninstall(src),
          ),
        );
      }
    }
    for (final lang in langKeys) {
      children.add(_HubSectionLabel(completeLanguageName(lang)));
      for (final src in byLang[lang]!) {
        children.add(
          _ActiveInstalledTile(
            src: src,
            repoLabel: _repoLabel(src),
            onBrowse: () => onBrowse(src),
            onUpdate: () => onUpdate(src),
            onUninstall: () => onUninstall(src),
          ),
        );
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => StaggeredFadeScale(index: i, child: children[i]),
    );
  }
}

class _UntrustedTile extends StatelessWidget {
  final ExtensionSource src;
  final VoidCallback onTrust;
  final VoidCallback onUninstall;

  const _UntrustedTile({
    required this.src,
    required this.onTrust,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _hubCardDecoration(c, accent: true),
      child: Row(
        children: [
          _buildIcon(
            src.apkPath.isNotEmpty
                ? _extractPkgFromApkPath(src.apkPath)
                : (src.pkgName.isNotEmpty ? src.pkgName : src.sourceId),
            c,
            iconUrl: src.iconUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  src.name,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Untrusted · v${src.version}',
                  style: TextStyle(color: c.accent, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTrust,
            style: TextButton.styleFrom(
              backgroundColor: c.accent.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              'Trust',
              style: TextStyle(color: c.accent, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.textSecondary),
            onPressed: onUninstall,
            tooltip: 'Uninstall',
          ),
        ],
      ),
    );
  }
}

class _ActiveInstalledTile extends StatelessWidget {
  final ExtensionSource src;
  final String repoLabel;
  final VoidCallback onBrowse;
  final VoidCallback onUpdate;
  final VoidCallback onUninstall;

  const _ActiveInstalledTile({
    required this.src,
    required this.repoLabel,
    required this.onBrowse,
    required this.onUpdate,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasUpdate = src.isUpdateAvailable;
    return AnimatedPress(
      onTap: onBrowse,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _hubCardDecoration(c, accent: hasUpdate),
        child: Row(
          children: [
            _buildIcon(
              src.apkPath.isNotEmpty
                  ? _extractPkgFromApkPath(src.apkPath)
                  : (src.pkgName.isNotEmpty ? src.pkgName : src.sourceId),
              c,
              iconUrl: src.iconUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    src.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (hasUpdate && src.versionLast != null) ...[
                    Text(
                      'Update available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'v${src.version} → v${src.versionLast}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accent.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'v${src.version} · ${src.lang}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: c.border.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            repoLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (hasUpdate) ...[
              TextButton(
                onPressed: onUpdate,
                style: TextButton.styleFrom(
                  backgroundColor: c.accent.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  'Update',
                  style: TextStyle(color: c.accent, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: Icon(Icons.info_outline, color: c.textSecondary, size: 20),
              onPressed: () => Navigator.push(
                context,
                _scaleFadeRoute(
                  ExtensionDetailScreen(source: src, onUninstall: onUninstall),
                ),
              ),
              tooltip: 'Info',
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, color: c.textSecondary),
              onPressed: onUninstall,
              tooltip: 'Unload',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Update-all banner ──────────────────────────────────────────────────
class _UpdateAllBanner extends StatelessWidget {
  final int count;
  final VoidCallback onUpdateAll;

  const _UpdateAllBanner({required this.count, required this.onUpdateAll});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _hubCardDecoration(c, accent: true),
      child: Row(
        children: [
          Icon(Icons.system_update_alt, size: 20, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count update${count == 1 ? '' : 's'} available',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap Update all to download and reload newer versions.',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUpdateAll,
            style: TextButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.bg,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Update all'),
          ),
        ],
      ),
    );
  }
}

// ─── Available tab — mangayomi 3-section layout ──────────────────────
class _AvailableTab extends StatefulWidget {
  final List<ExtensionRepo> repos;
  final Map<int, List<ExtensionIndexEntry>> indexCache;
  final Set<int> loading;
  final List<ExtensionSource> installed;
  final bool showNsfw;
  final bool showOnlyNsfw;
  final String langFilter;
  final Set<String> typeFilters;
  final bool showObsolete;
  final void Function(ExtensionRepo) onFetch;
  final VoidCallback onFetchAll;
  final void Function(ExtensionIndexEntry, ExtensionRepo) onInstall;
  final VoidCallback onSeed;

  const _AvailableTab({
    required this.repos,
    required this.indexCache,
    required this.loading,
    required this.installed,
    required this.showNsfw,
    required this.showOnlyNsfw,
    required this.langFilter,
    required this.typeFilters,
    required this.showObsolete,
    required this.onFetch,
    required this.onFetchAll,
    required this.onInstall,
    required this.onSeed,
  });

  @override
  State<_AvailableTab> createState() => _AvailableTabState();
}

/// Languages to show in the extension browser.
const _allowedLanguages = ['all', 'en', 'es', 'fr', 'it', 'la', 'nl'];
const _allowedLanguageSet = {'all', 'en', 'es', 'fr', 'it', 'la', 'nl'};

class _AvailableTabState extends State<_AvailableTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  List<_AvailableRow>? _cachedRows;
  int _rowsCacheKey = 0;

  @override
  void initState() {
    super.initState();
    // Debounce search so every keystroke does not rebuild ~700 rows.
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final repo in widget.repos) {
        if (!widget.indexCache.containsKey(repo.id)) {
          widget.onFetch(repo);
        }
      }
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final text = _searchCtrl.text;
    // Clear instantly; filter only after a short pause for typing.
    if (text.isEmpty) {
      if (_query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (_query != text) setState(() => _query = text);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_AvailableRow> _buildRowsCached({
    required bool showNsfw,
    required bool showOnlyNsfw,
    required bool showObsolete,
  }) {
    final key = Object.hash(
      _query,
      widget.repos.length,
      widget.indexCache.length,
      widget.installed.length,
      showNsfw,
      showOnlyNsfw,
      showObsolete,
      widget.langFilter,
      Object.hashAll(widget.typeFilters),
      Object.hashAll(widget.loading),
    );
    if (_cachedRows != null && _rowsCacheKey == key) return _cachedRows!;
    _cachedRows = _buildRows(
      showNsfw: showNsfw,
      showOnlyNsfw: showOnlyNsfw,
      showObsolete: showObsolete,
    );
    _rowsCacheKey = key;
    return _cachedRows!;
  }

  List<_AvailableRow> _buildRows({
    required bool showNsfw,
    required bool showOnlyNsfw,
    required bool showObsolete,
  }) {
    final installedPkgs = _installedPkgs(widget.installed);
    final allEntries = <_EntryWithRepo>[];
    for (final repo in widget.repos) {
      final entries = widget.indexCache[repo.id];
      if (entries == null) continue;
      for (final e in entries) {
        if (installedPkgs.contains(e.pkg)) continue;
        allEntries.add(_EntryWithRepo(entry: e, repo: repo));
      }
    }

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allEntries
        : allEntries
              .where((er) => er.entry.name.toLowerCase().contains(query))
              .toList(growable: false);

    final notInstalledEntries = <_EntryWithRepo>[];

    for (final er in filtered) {
      final entry = er.entry;
      final lang = entry.lang.toLowerCase();
      if (!_allowedLanguageSet.contains(lang)) continue;
      if (widget.langFilter != 'all' && lang != widget.langFilter) continue;
      if (entry.sources.isEmpty && !entry.isJs && !entry.isDart) continue;
      // Show NSFW off → hide NSFW. Show only NSFW on → NSFW-only.
      if (!showNsfw && entry.isNsfw) continue;
      if (showNsfw && showOnlyNsfw && !entry.isNsfw) continue;
      if (!showObsolete && entry.isObsolete) continue;
      final typeOk =
          widget.typeFilters.isEmpty ||
          (entry.isMihon &&
              widget.typeFilters.contains(SourceCodeLanguage.mihon)) ||
          (entry.isJs && widget.typeFilters.contains(SourceCodeLanguage.js)) ||
          (entry.isDart &&
              widget.typeFilters.contains(SourceCodeLanguage.dart));
      if (!typeOk) continue;
      notInstalledEntries.add(er);
    }

    final rows = <_AvailableRow>[];

    // Static per-repo groups (always expanded — no accordion).
    final groups = <int, List<_EntryWithRepo>>{};
    for (final er in notInstalledEntries) {
      groups.putIfAbsent(er.repo.id, () => []).add(er);
    }

    final sortedRepos = List<ExtensionRepo>.from(widget.repos)
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final repo in sortedRepos) {
      final fetched = widget.indexCache.containsKey(repo.id);
      final group = groups[repo.id] ?? const <_EntryWithRepo>[];
      final loading = widget.loading.contains(repo.id);
      if (!fetched && group.isEmpty && !loading && query.isNotEmpty) {
        continue;
      }
      final sortedGroup = List<_EntryWithRepo>.from(group)
        ..sort((a, b) => a.entry.name.compareTo(b.entry.name));
      rows.add(
        _AvailableRow.repoHeader(
          repoId: repo.id,
          repoName: repo.name,
          count: sortedGroup.length,
        ),
      );
      if (!fetched) {
        rows.add(_AvailableRow.pendingFetch(repoId: repo.id, loading: loading));
      } else {
        for (final er in sortedGroup) {
          rows.add(_AvailableRow.entry(er, installed: false, hasUpdate: false));
        }
        if (sortedGroup.isEmpty) {
          rows.add(
            _AvailableRow.emptyMessage(
              query.isNotEmpty
                  ? 'No matches in ${repo.name}'
                  : 'No extensions in ${repo.name}',
            ),
          );
        }
      }
    }

    if (rows.isEmpty && allEntries.isNotEmpty) {
      rows.add(
        _AvailableRow.emptyMessage(
          query.isNotEmpty
              ? 'No extensions match "$_query"'
              : 'No extensions available',
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.repos.isEmpty) {
      return EmptyState(
        icon: AppIcons.cloudLoading,
        emoji: '☁️',
        title: 'No repos yet',
        subtitle:
            'Tap below to add the official Keiyoushi repo, then fetch its index.',
        primaryActionLabel: 'Add Keiyoushi repo',
        onPrimaryAction: widget.onSeed,
        pillPrimary: true,
      );
    }

    final rows = _buildRowsCached(
      showNsfw: widget.showNsfw,
      showOnlyNsfw: widget.showOnlyNsfw,
      showObsolete: widget.showObsolete,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
            cursorColor: c.accent,
            decoration: InputDecoration(
              hintText: 'Find a source…',
              hintStyle: TextStyle(
                color: c.textTertiary,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              prefixIcon: Icon(Icons.search, size: 20, color: c.textTertiary),
              suffixIcon: _query.isNotEmpty || _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, size: 18, color: c.textTertiary),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: c.bgElevated,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.borderStrong),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.accent, width: 1.5),
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: c.border),
              ),
            ),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                Widget built;
                switch (row.kind) {
                  case _AvailableRowKind.repoHeader:
                    built = _HubSectionLabel(
                      row.title!,
                      trailing: '${row.count}',
                    );
                  case _AvailableRowKind.pendingFetch:
                    final repo = widget.repos.firstWhere(
                      (r) => r.id == row.repoId,
                    );
                    built = Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _hubCardDecoration(c),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.loading
                                  ? 'Fetching catalogue…'
                                  : 'Catalogue not loaded yet',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: row.loading
                                ? null
                                : () => widget.onFetch(repo),
                            icon: row.loading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(row.loading ? '…' : 'Fetch'),
                          ),
                        ],
                      ),
                    );
                  case _AvailableRowKind.entry:
                    final er = row.entry!;
                    built = _ExtensionRow(
                      entry: er.entry,
                      installed: row.installed,
                      hasUpdate: row.hasUpdate,
                      installedVersion: row.installedVersion,
                      onInstall: () => widget.onInstall(er.entry, er.repo),
                    );
                  case _AvailableRowKind.emptyMessage:
                    built = Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        row.title ?? '',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StaggeredFadeScale(index: index, child: built),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum _AvailableRowKind { repoHeader, pendingFetch, entry, emptyMessage }

class _AvailableRow {
  final _AvailableRowKind kind;
  final String? title;
  final _EntryWithRepo? entry;
  final bool installed;
  final bool hasUpdate;
  final String? installedVersion;
  final int? repoId;
  final int count;
  final bool loading;

  const _AvailableRow._({
    required this.kind,
    this.title,
    this.entry,
    this.installed = false,
    this.hasUpdate = false,
    this.installedVersion,
    this.repoId,
    this.count = 0,
    this.loading = false,
  });

  const _AvailableRow.emptyMessage(String message)
    : this._(kind: _AvailableRowKind.emptyMessage, title: message);

  const _AvailableRow.repoHeader({
    required int repoId,
    required String repoName,
    required int count,
  }) : this._(
         kind: _AvailableRowKind.repoHeader,
         title: repoName,
         repoId: repoId,
         count: count,
       );

  const _AvailableRow.pendingFetch({required int repoId, required bool loading})
    : this._(
        kind: _AvailableRowKind.pendingFetch,
        repoId: repoId,
        loading: loading,
      );

  const _AvailableRow.entry(
    _EntryWithRepo entry, {
    required bool installed,
    required bool hasUpdate,
    String? installedVersion,
  }) : this._(
         kind: _AvailableRowKind.entry,
         entry: entry,
         installed: installed,
         hasUpdate: hasUpdate,
         installedVersion: installedVersion,
       );
}

class _EntryWithRepo {
  final ExtensionIndexEntry entry;
  final ExtensionRepo repo;
  const _EntryWithRepo({required this.entry, required this.repo});
}

extension on ExtensionIndexEntry {
  bool get isObsolete => false;
}

class _ExtensionRow extends StatelessWidget {
  final ExtensionIndexEntry entry;
  final bool installed;
  final bool hasUpdate;
  final String? installedVersion;
  final VoidCallback onInstall;

  const _ExtensionRow({
    required this.entry,
    required this.installed,
    this.hasUpdate = false,
    this.installedVersion,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isNsfw = entry.isNsfw;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _hubCardDecoration(c, accent: hasUpdate),
      child: Row(
        children: [
          _buildIcon(entry.pkg, c, iconUrl: entry.iconUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNsfw) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(204),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NSFW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasUpdate && installedVersion != null
                      ? '${completeLanguageName(entry.lang)} · '
                            '$installedVersion → ${entry.version}'
                      : '${completeLanguageName(entry.lang)} · v${entry.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasUpdate ? c.accent : c.textSecondary,
                    fontSize: 12,
                    fontWeight: hasUpdate ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: hasUpdate ? onInstall : (installed ? null : onInstall),
            style: TextButton.styleFrom(
              backgroundColor: (hasUpdate || !installed)
                  ? c.accent.withValues(alpha: 0.12)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              hasUpdate
                  ? 'Update'
                  : installed
                  ? 'Loaded'
                  : 'Load',
              style: TextStyle(
                color: installed && !hasUpdate ? c.textTertiary : c.accent,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Repos tab ──────────────────────────────────────────────────────────
class _ReposTab extends StatelessWidget {
  final List<ExtensionRepo> repos;
  final VoidCallback onAdd;
  final void Function(ExtensionRepo) onRemove;

  const _ReposTab({
    required this.repos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        if (repos.isEmpty)
          EmptyState(
            icon: AppIcons.globe,
            emoji: '🌐',
            title: 'No repos yet',
            subtitle: 'Add a repo to discover extensions.',
            primaryActionLabel: 'Add repo',
            onPrimaryAction: onAdd,
            pillPrimary: true,
          )
        else
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: repos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = repos[i];
              return StaggeredFadeScale(
                index: i,
                child: AnimatedPress(
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: r.url));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${r.url}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _hubCardDecoration(c),
                    child: Row(
                      children: [
                        Icon(Icons.cloud, color: c.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.url,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: c.textSecondary,
                          ),
                          onPressed: () => onRemove(r),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AethelgardFab(iconData: AppIcons.add, onPressed: onAdd),
        ),
      ],
    );
  }
}

// ─── Shared empty state removed — use widgets/empty_state.dart EmptyState.

/// Shared icon widget for extension list tiles.
///
/// Resolves the icon URL from the package name via [ExtensionIconCache]:
///   1. The persisted cache (fast SharedPreferences read) — authoritative
///      `resources.iconUrl` from the one-time full-index fetch.
///   2. The deterministic CDN derivation (`iconUrlForPkg`) — used as the
///      instant initial value so there is no flicker, and as the fallback
///      when the cache has no entry.
///
/// This never reads the stale `.../repo/icon/${pkg}.png` value that older DB
/// rows may still hold, so already-installed extensions self-heal without a
/// migration. See Q5.
Widget _buildIcon(
  String pkg,
  KomaColors c, {
  double size = 37,
  String? iconUrl,
}) {
  return _PkgExtensionIcon(pkg: pkg, colors: c, size: size, iconUrl: iconUrl);
}

class _PkgExtensionIcon extends StatefulWidget {
  final String pkg;
  final KomaColors colors;
  final double size;
  final String? iconUrl;

  const _PkgExtensionIcon({
    required this.pkg,
    required this.colors,
    required this.size,
    this.iconUrl,
  });

  @override
  State<_PkgExtensionIcon> createState() => _PkgExtensionIconState();
}

class _PkgExtensionIconState extends State<_PkgExtensionIcon> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bootstrapUrl();
  }

  void _bootstrapUrl() {
    _failed = false;
    _url = ExtensionIconCache.initialDisplayUrl(
      pkg: widget.pkg,
      iconUrl: widget.iconUrl,
    );
    _resolveFromCache();
  }

  @override
  void didUpdateWidget(covariant _PkgExtensionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconUrl != widget.iconUrl || oldWidget.pkg != widget.pkg) {
      _bootstrapUrl();
    }
  }

  Future<void> _resolveFromCache() async {
    final cached = await ExtensionIconCache.instance.cachedIconUrl(widget.pkg);
    if (!mounted || _failed) return;
    if (cached != null &&
        cached.isNotEmpty &&
        cached != _url &&
        !ExtensionIconCache.isLegacyBrokenIconUrl(cached)) {
      setState(() => _url = cached);
    }
  }

  Future<void> _retryAfterLoadError() async {
    if (_failed || !mounted) return;
    final resolved = await ExtensionIconCache.instance.resolveIconUrl(
      widget.pkg,
    );
    if (!mounted || _failed) return;
    if (resolved != null &&
        resolved.isNotEmpty &&
        resolved != _url &&
        !ExtensionIconCache.isLegacyBrokenIconUrl(resolved)) {
      setState(() => _url = resolved);
      return;
    }
    _markFailed();
  }

  void _markFailed() {
    if (_failed || !mounted) return;
    setState(() {
      _failed = true;
      _url = null;
    });
  }

  Widget _placeholder(double size, KomaColors c) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.extension_rounded, color: c.accent, size: size * 0.75),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final size = widget.size;
    final c = widget.colors;
    if (_failed || url == null || url.isEmpty) {
      return _placeholder(size, c);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image(
          image: CustomExtendedNetworkImageProvider(url, printError: false),
          fit: BoxFit.contain,
          width: size,
          height: size,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _retryAfterLoadError(),
            );
            return _placeholder(size, c);
          },
        ),
      ),
    );
  }
}


