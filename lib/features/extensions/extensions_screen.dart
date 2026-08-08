import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/extension_repo.dart';
import '../../core/models/extension_source.dart';
import '../../core/providers.dart';
import '../../core/services/extension_icon_cache.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import '../../core/utils/language.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/aethelgard_fab.dart';
import '../../widgets/animated_press.dart';
import 'extension_detail_screen.dart';
import 'source_browse_screen.dart';

const _keiyoushiDefaultRepoUrl =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.json';
const _keiyoushiDefaultRepoName = 'Keiyoushi (official)';

String _extractPkgFromApkPath(String apkPath) {
  final fileName = apkPath.split('/').last;
  if (fileName.endsWith('.apk')) {
    return fileName.substring(0, fileName.length - 4);
  }
  return fileName;
}

Set<String> _installedPkgs(List<ExtensionSource> installed) {
  final set = <String>{};
  for (final s in installed) {
    final pkg = _extractPkgFromApkPath(s.apkPath);
    if (pkg.isNotEmpty) set.add(pkg);
    // JS installs store the catalog id on sourceId/id (no APK path).
    if (s.isJs) {
      if (s.sourceId.isNotEmpty) set.add(s.sourceId);
      if (s.id.isNotEmpty) set.add(s.id);
    }
  }
  return set;
}

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final ExtensionManager _mgr;

  List<ExtensionRepo> _repos = const [];
  List<ExtensionSource> _installed = const [];

  // Map<repoId, List<ExtensionIndexEntry>> (all entries, installed or not).
  // Needed to resolve an `ExtensionIndexEntry` + repo when updating an
  // already-installed extension via ExtensionManager.updateSource.
  final Map<int, List<ExtensionIndexEntry>> _fullIndexCache = {};

  // Map<repoId, List<ExtensionIndexEntry>> (only not-installed entries).
  final Map<int, List<ExtensionIndexEntry>> _indexCache = {};
  final Set<int> _loadingIndex = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // ref.read (not watch) — initState must not subscribe to providers.
    _mgr = ExtensionManager(ref.read(repositoriesProvider), KeiyoushiService());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      // Reconcile before listing so Untrusted rows show correctly.
      try {
        await _mgr.reconcileTrust();
      } catch (_) {}
      final repos = await _mgr.listRepos();
      final installed = await _mgr.listInstalled();
      if (!mounted) return;
      setState(() {
        _repos = repos;
        _installed = installed;
        _error = null;
      });
      ref.read(extensionUpdateCountProvider.notifier).refresh();
      // One-time population of the pkg→iconUrl cache from the full Keiyoushi
      // index. No-op after the first run; failures are swallowed internally
      // so icon resolution degrades to the CDN derivation fallback.
      // See Q5.
      _mgr.refreshIconCache();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Mihon Untrusted dialog — Trust continues install/update; Uninstall discards.
  Future<bool> _confirmTrust(UntrustedExtensionException e) async {
    final c = context.colors;
    final action = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Untrusted extension',
          style: TextStyle(color: c.textPrimary),
        ),
        content: Text(
          '${e.info.packageName} is not signed by a known repository. '
          'Installing it may put your device and data at risk.',
          style: TextStyle(color: c.textSecondary),
        ),
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

  Future<void> _fetchIndex(ExtensionRepo repo) async {
    if (_loadingIndex.contains(repo.id)) return;
    setState(() => _loadingIndex.add(repo.id));
    try {
      final entries = await _mgr.fetchIndex(repo);
      if (!mounted) return;
      await _mgr.checkForObsoleteSources(entries, repo.url);
      await _mgr.checkForUpdates(entries, repo.url);
      if (!mounted) return;
      final installed = await _mgr.listInstalled();
      if (!mounted) return;
      final loadedPkgs = _installedPkgs(installed);
      setState(() {
        _fullIndexCache[repo.id] = entries;
        _indexCache[repo.id] = entries
            .where((e) => !loadedPkgs.contains(e.pkg))
            .toList(growable: false);
        _installed = installed;
        _error = null;
      });
      ref.read(extensionUpdateCountProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _loadingIndex.remove(repo.id));
      }
    }
  }

  Future<void> _addRepoDialog() async {
    final nameCtl = TextEditingController();
    final urlCtl = TextEditingController();
    var kind = ExtensionRepoKind.mihon;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: c.surface,
              title: Text('Add repo', style: TextStyle(color: c.textPrimary)),
              content: Column(
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
                      labelText: 'index.json URL',
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtl.text.trim().isEmpty ||
                        urlCtl.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
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
    await _mgr.removeRepo(repo.id);
    setState(() => _indexCache.remove(repo.id));
    await _refresh();
  }

  Future<void> _install(ExtensionIndexEntry entry, ExtensionRepo repo) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Loading ${entry.name}...')));
    try {
      final src = await _mgr.install(entry, repoUrl: repo.url);
      messenger.showSnackBar(SnackBar(content: Text('Loaded ${src.name}')));
      setState(() {
        _installed = List.from(_installed)..add(src);
        _indexCache[repo.id] =
            _indexCache[repo.id]
                ?.where((e) => e.pkg != entry.pkg)
                .toList(growable: false) ??
            const [];
      });
      await _fetchIndex(repo);
    } on UnsupportedExtensionLanguageException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Dart-eval is unsupported'
            '${e.name != null && e.name!.isNotEmpty ? ' (${e.name})' : ''}',
          ),
        ),
      );
    } on UntrustedExtensionException catch (e) {
      // JS installs never go through APK trust — skip the dialog path.
      if (entry.isJs) {
        messenger.showSnackBar(
          SnackBar(content: Text('Load failed for JS source ${entry.name}')),
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
      setState(() {
        _installed = _installed
            .where((s) => s.sourceId != src.sourceId)
            .toList();
      });
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
        } else if (src.isJs &&
            e.isJs &&
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
    if (target != null && target.isNotEmpty) {
      final exact = candidates
          .where((c) => c.entry.version == target)
          .firstOrNull;
      if (exact != null) return exact;
    }

    // Newest entry that is actually newer than the installed version.
    candidates.sort(
      (a, b) => compareVersions(b.entry.version, a.entry.version),
    );
    for (final c in candidates) {
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
      final kind = src.isJs
          ? ExtensionRepoKind.javascript
          : ExtensionRepoKind.mihon;
      reposToFetch.addAll(
        _repos.where((r) => r.enabled && r.kind == kind),
      );
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
            'Dart-eval is unsupported'
            '${e.name != null && e.name!.isNotEmpty ? ' (${e.name})' : ''}',
          ),
        ),
      );
    } on UntrustedExtensionException catch (e) {
      if (src.isJs || resolved.entry.isJs) {
        messenger.showSnackBar(
          SnackBar(content: Text('Update failed for JS source ${src.name}')),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('Extensions', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Global search',
            icon: Icon(Icons.travel_explore, color: c.textPrimary),
            onPressed: () => context.pushNamed(Routes.globalSearch),
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
                  onUninstall: _uninstall,
                  onUpdate: _update,
                  onUpdateAll: _updateAll,
                  onTrust: _trustExisting,
                  onBrowse: (src) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SourceBrowseScreen(
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
                  showObsolete: theme.showObsoleteExtensions,
                  onFetch: _fetchIndex,
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
class _InstalledTab extends StatelessWidget {
  final List<ExtensionSource> installed;
  final void Function(ExtensionSource) onUninstall;
  final void Function(ExtensionSource) onUpdate;
  final VoidCallback onUpdateAll;
  final void Function(ExtensionSource) onTrust;
  final void Function(ExtensionSource) onBrowse;

  const _InstalledTab({
    required this.installed,
    required this.onUninstall,
    required this.onUpdate,
    required this.onUpdateAll,
    required this.onTrust,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (installed.isEmpty) {
      return _EmptyState(
        icon: Icons.extension_outlined,
        title: 'Nothing installed yet',
        subtitle: 'Open the Available tab to load your first extension.',
      );
    }

    // One tile per APK — active first, then Untrusted section.
    final byApk = <String, ExtensionSource>{};
    for (final s in installed) {
      final key = s.apkPath.isNotEmpty ? s.apkPath : s.sourceId;
      byApk.putIfAbsent(key, () => s);
    }
    final unique = byApk.values.toList();
    final untrusted = unique
        .where((s) => s.isUntrusted || (!s.isActive && s.apkPath.isNotEmpty))
        .toList();
    final active = unique
        .where((s) => s.isActive)
        .toList();
    final updates = active.where((s) => s.isUpdateAvailable).toList();

    final children = <Widget>[];
    if (updates.isNotEmpty) {
      children.add(
        _UpdateAllBanner(count: updates.length, onUpdateAll: onUpdateAll),
      );
    }
    if (untrusted.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            'Untrusted',
            style: TextStyle(
              color: c.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
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
    if (active.isNotEmpty && untrusted.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            'Loaded',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    for (final src in active) {
      children.add(
        _ActiveInstalledTile(
          src: src,
          onBrowse: () => onBrowse(src),
          onUpdate: () => onUpdate(src),
          onUninstall: () => onUninstall(src),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => children[i],
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
      decoration: BoxDecoration(
        color: c.accentMuted.withValues(alpha: 0.25),
        borderRadius: AppSpacing.brMd,
        border: Border.all(color: c.accent.withValues(alpha: 0.5)),
      ),
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
  final VoidCallback onBrowse;
  final VoidCallback onUpdate;
  final VoidCallback onUninstall;

  const _ActiveInstalledTile({
    required this.src,
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
        decoration: BoxDecoration(
          color: hasUpdate
              ? c.accentMuted.withValues(alpha: 0.35)
              : c.surface,
          borderRadius: AppSpacing.brMd,
          border: Border.all(
            color: hasUpdate ? c.accent.withValues(alpha: 0.6) : c.border,
          ),
        ),
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
                            src.isJs ? 'JS' : 'Mihon',
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
              icon: Icon(
                Icons.info_outline,
                color: c.textSecondary,
                size: 20,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExtensionDetailScreen(
                    source: src,
                    onUninstall: onUninstall,
                  ),
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
      decoration: BoxDecoration(
        color: c.accentMuted.withValues(alpha: 0.5),
        borderRadius: AppSpacing.brMd,
        border: Border.all(color: c.accent.withValues(alpha: 0.6)),
      ),
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
  final bool showObsolete;
  final void Function(ExtensionRepo) onFetch;
  final void Function(ExtensionIndexEntry, ExtensionRepo) onInstall;
  final VoidCallback onSeed;

  const _AvailableTab({
    required this.repos,
    required this.indexCache,
    required this.loading,
    required this.installed,
    required this.showNsfw,
    required this.showObsolete,
    required this.onFetch,
    required this.onInstall,
    required this.onSeed,
  });

  @override
  State<_AvailableTab> createState() => _AvailableTabState();
}

/// Languages to show in the extension browser.
const _allowedLanguages = {'all', 'en', 'es', 'fr', 'it', 'la', 'nl'};

class _AvailableTabState extends State<_AvailableTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  /// Repo ids whose not-installed section is collapsed. Empty = all expanded.
  final Set<int> _collapsedRepos = {};
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
    required bool showObsolete,
  }) {
    final key = Object.hash(
      _query,
      widget.repos.length,
      widget.indexCache.length,
      widget.installed.length,
      _collapsedRepos.length,
      showNsfw,
      showObsolete,
    );
    if (_cachedRows != null && _rowsCacheKey == key) return _cachedRows!;
    _cachedRows = _buildRows(showNsfw: showNsfw, showObsolete: showObsolete);
    _rowsCacheKey = key;
    return _cachedRows!;
  }

  List<_AvailableRow> _buildRows({
    required bool showNsfw,
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
      if (!_allowedLanguages.contains(er.entry.lang.toLowerCase())) continue;
      final entry = er.entry;
      if (entry.sources.isEmpty && !entry.isJs) continue;
      if (!showNsfw && entry.isNsfw) continue;
      if (!showObsolete && entry.isObsolete) continue;
      notInstalledEntries.add(er);
    }

    final rows = <_AvailableRow>[];

    void appendKindSection(String title, String kind) {
      final kindEntries = notInstalledEntries
          .where((er) => er.repo.kind == kind)
          .toList(growable: false);
      if (kindEntries.isEmpty) return;

      rows.add(_AvailableRow.section(title));

      final groups = <int, List<_EntryWithRepo>>{};
      for (final er in kindEntries) {
        groups.putIfAbsent(er.repo.id, () => []).add(er);
      }
      final sortedIds = groups.keys.toList()
        ..sort((a, b) {
          final repoA = widget.repos.firstWhere((r) => r.id == a);
          final repoB = widget.repos.firstWhere((r) => r.id == b);
          return repoA.name.compareTo(repoB.name);
        });

      for (final repoId in sortedIds) {
        final repo = widget.repos.firstWhere((r) => r.id == repoId);
        final group = groups[repoId]!
          ..sort((a, b) => a.entry.name.compareTo(b.entry.name));
        final expanded = !_collapsedRepos.contains(repoId);
        rows.add(
          _AvailableRow.repoHeader(
            repoId: repoId,
            repoName: repo.name,
            count: group.length,
            expanded: expanded,
          ),
        );
        if (expanded) {
          for (final er in group) {
            rows.add(
              _AvailableRow.entry(er, installed: false, hasUpdate: false),
            );
          }
        }
      }
    }

    appendKindSection('Mihon (APK)', ExtensionRepoKind.mihon);
    appendKindSection('JavaScript', ExtensionRepoKind.javascript);

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
      return _EmptyState(
        icon: Icons.cloud_download_outlined,
        title: 'No repos yet',
        subtitle:
            'Tap below to add the official Keiyoushi repo, then fetch its index.',
        action: FilledButton.icon(
          onPressed: widget.onSeed,
          icon: const Icon(Icons.add),
          label: const Text('Add Keiyoushi repo'),
        ),
      );
    }

    final hasAnyFetched = widget.repos.any(
      (r) => widget.indexCache.containsKey(r.id),
    );
    final rows = hasAnyFetched
        ? _buildRowsCached(
            showNsfw: widget.showNsfw,
            showObsolete: widget.showObsolete,
          )
        : const <_AvailableRow>[];

    return Column(
      children: [
        if (hasAnyFetched)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search extensions…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty || _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.brMd,
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
          ),
        Expanded(
          child: !hasAnyFetched
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final repo in widget.repos) ...[
                      _RepoHeader(
                        repo: repo,
                        loading: widget.loading.contains(repo.id),
                        onFetch: () => widget.onFetch(repo),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Tap "Fetch" to load extensions from this repo.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              : RepaintBoundary(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      switch (row.kind) {
                        case _AvailableRowKind.section:
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: 8,
                              top: index == 0 ? 0 : 8,
                            ),
                            child: Text(
                              row.title!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: c.textPrimary,
                              ),
                            ),
                          );
                        case _AvailableRowKind.repoHeader:
                          return _RepoGroupHeader(
                            repoName: row.title!,
                            count: row.count,
                            expanded: row.expanded,
                            onToggle: () {
                              final id = row.repoId!;
                              setState(() {
                                if (row.expanded) {
                                  _collapsedRepos.add(id);
                                } else {
                                  _collapsedRepos.remove(id);
                                }
                              });
                            },
                          );
                        case _AvailableRowKind.entry:
                          final er = row.entry!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _ExtensionRow(
                              entry: er.entry,
                              installed: row.installed,
                              hasUpdate: row.hasUpdate,
                              installedVersion: row.installedVersion,
                              onInstall: () =>
                                  widget.onInstall(er.entry, er.repo),
                            ),
                          );
                        case _AvailableRowKind.emptyMessage:
                          return Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: c.textTertiary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    row.title!,
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

enum _AvailableRowKind { section, repoHeader, entry, emptyMessage }

class _AvailableRow {
  final _AvailableRowKind kind;
  final String? title;
  final _EntryWithRepo? entry;
  final bool installed;
  final bool hasUpdate;
  final String? installedVersion;
  final int? repoId;
  final int count;
  final bool expanded;

  const _AvailableRow._({
    required this.kind,
    this.title,
    this.entry,
    this.installed = false,
    this.hasUpdate = false,
    this.installedVersion,
    this.repoId,
    this.count = 0,
    this.expanded = true,
  });

  const _AvailableRow.section(String title)
    : this._(kind: _AvailableRowKind.section, title: title);

  const _AvailableRow.emptyMessage(String message)
    : this._(kind: _AvailableRowKind.emptyMessage, title: message);

  const _AvailableRow.repoHeader({
    required int repoId,
    required String repoName,
    required int count,
    required bool expanded,
  }) : this._(
         kind: _AvailableRowKind.repoHeader,
         title: repoName,
         repoId: repoId,
         count: count,
         expanded: expanded,
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

class _RepoHeader extends StatelessWidget {
  final ExtensionRepo repo;
  final bool loading;
  final VoidCallback onFetch;

  const _RepoHeader({
    required this.repo,
    required this.loading,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repo.name,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                repo.url,
                style: TextStyle(color: c.textSecondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: loading ? null : onFetch,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 16),
          label: const Text('Fetch'),
        ),
      ],
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasUpdate ? c.accent.withAlpha(15) : c.surface,
        borderRadius: AppSpacing.brMd,
        border: Border.all(
          color: hasUpdate ? c.accent.withAlpha(51) : c.border,
        ),
      ),
      child: Row(
        children: [
          _buildIcon(entry.pkg, c, size: 28, iconUrl: entry.iconUrl),
          const SizedBox(width: 10),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNsfw) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(204),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NSFW',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      completeLanguageName(entry.lang),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (hasUpdate && installedVersion != null)
                      Text(
                        '$installedVersion → ${entry.version}',
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        'v${entry.version}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: hasUpdate ? onInstall : (installed ? null : onInstall),
            child: Text(
              hasUpdate
                  ? 'Update'
                  : installed
                  ? 'Loaded'
                  : 'Load',
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
          _EmptyState(
            icon: Icons.cloud_outlined,
            title: 'No repos',
            subtitle: 'Add a repo to discover extensions.',
          )
        else
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: repos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = repos[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: AppSpacing.brMd,
                  border: Border.all(color: c.border),
                ),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            r.url,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: c.textSecondary),
                      onPressed: () => onRemove(r),
                    ),
                  ],
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

// ─── Shared empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

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
    if (widget.iconUrl != null && widget.iconUrl!.isNotEmpty) {
      _url = widget.iconUrl;
    } else {
      _url = ExtensionIconCache.iconUrlForPkg(widget.pkg);
      _resolveFromCache();
    }
  }

  @override
  void didUpdateWidget(covariant _PkgExtensionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconUrl != widget.iconUrl || oldWidget.pkg != widget.pkg) {
      _failed = false;
      if (widget.iconUrl != null && widget.iconUrl!.isNotEmpty) {
        _url = widget.iconUrl;
      } else {
        _url = ExtensionIconCache.iconUrlForPkg(widget.pkg);
        _resolveFromCache();
      }
    }
  }

  Future<void> _resolveFromCache() async {
    if (_url != null && _url!.isNotEmpty) return;
    final cached = await ExtensionIconCache.instance.cachedIconUrl(widget.pkg);
    if (!mounted || _failed) return;
    if (cached != null && cached.isNotEmpty) {
      setState(() => _url = cached);
    }
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
      child: Icon(
        Icons.extension_rounded,
        color: c.accent,
        size: size * 0.75,
      ),
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
            WidgetsBinding.instance.addPostFrameCallback((_) => _markFailed());
            return _placeholder(size, c);
          },
        ),
      ),
    );
  }
}

/// Collapsible repo group header used by the lazy Available list.
class _RepoGroupHeader extends StatelessWidget {
  final String repoName;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  const _RepoGroupHeader({
    required this.repoName,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: c.textSecondary,
            ),
            const SizedBox(width: 4),
            Icon(Icons.cloud_outlined, size: 14, color: c.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                repoName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: c.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
