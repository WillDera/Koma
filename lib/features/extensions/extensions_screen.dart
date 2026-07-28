import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/models/extension_repo.dart';
import '../../core/models/extension_source.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import '../../core/utils/language.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import 'extension_detail_screen.dart';
import 'source_browse_screen.dart';

const _keiyoushiDefaultRepoUrl =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
const _keiyoushiDefaultRepoName = 'Keiyoushi (official)';

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
  // Map<repoId, List<ExtensionIndexEntry>>
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
      final repos = await _mgr.listRepos();
      final installed = await _mgr.listInstalled();
      if (!mounted) return;
      setState(() {
        _repos = repos;
        _installed = installed;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _ensureRepoSeeded() async {
    if (_repos.isNotEmpty) return;
    await _mgr.addRepo(
      name: _keiyoushiDefaultRepoName,
      url: _keiyoushiDefaultRepoUrl,
    );
    await _refresh();
  }

  Future<void> _fetchIndex(ExtensionRepo repo) async {
    if (_loadingIndex.contains(repo.id)) return;
    setState(() => _loadingIndex.add(repo.id));
    try {
      final entries = await _mgr.fetchIndex(repo);
      if (!mounted) return;
      // Check for obsolete sources after fetching fresh index (mangayomi pattern)
      await _mgr.checkForObsoleteSources(entries, repo.url);
      // Reload installed list since obsolete flags may have changed
      if (!mounted) return;
      final installed = await _mgr.listInstalled();
      if (!mounted) return;
      setState(() {
        _indexCache[repo.id] = entries;
        _installed = installed;
        _error = null;
      });
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Add repo', style: TextStyle(color: c.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
    if (ok == true) {
      await _mgr.addRepo(name: nameCtl.text.trim(), url: urlCtl.text.trim());
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
    // Confirm install — matching Mihon's pattern
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Install extension', style: TextStyle(color: c.textPrimary)),
          content: Text(
            'Install ${entry.name} v${entry.version}?',
            style: TextStyle(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Install'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      final src = await _mgr.install(entry, repoUrl: repo.url);
      messenger.showSnackBar(
        SnackBar(content: Text('Installed ${src.name}')),
      );
      // Reload the index to show installed state
      await _fetchIndex(repo);
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Install failed: $e')),
      );
    }
  }

  Future<void> _uninstall(ExtensionSource src) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _mgr.uninstall(src);
      messenger.showSnackBar(
        SnackBar(content: Text('Uninstalled ${src.name}')),
      );
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Uninstall failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('Extensions', style: TextStyle(color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: c.accent,
          labelColor: c.accent,
          unselectedLabelColor: c.textSecondary,
          tabs: const [
            Tab(text: 'Installed'),
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
                  onBrowse: (src) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SourceBrowseScreen(
                        sourceId: src.id,
                        sourceName: src.name,
                      ),
                    ),
                  ),
                ),
                _AvailableTab(
                  repos: _repos,
                  indexCache: _indexCache,
                  loading: _loadingIndex,
                  installed: _installed,
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
  final void Function(ExtensionSource) onBrowse;

  const _InstalledTab({
    required this.installed,
    required this.onUninstall,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (installed.isEmpty) {
      return _EmptyState(
        icon: Icons.extension_outlined,
        title: 'Nothing installed yet',
        subtitle: 'Open the Available tab to install your first extension.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: installed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final src = installed[i];
        return AnimatedPress(
          onTap: () => onBrowse(src),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: AppSpacing.brMd,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                _buildIcon(src.iconUrl, c),
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
                        'v${src.version} · ${src.lang}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, color: c.textSecondary, size: 20),
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ExtensionDetailScreen(
                      source: src,
                      onUninstall: () => onUninstall(src),
                    )),
                  ),
                  tooltip: 'Info',
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: c.textSecondary),
                  onPressed: () => onUninstall(src),
                  tooltip: 'Uninstall',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Available tab — mangayomi 3-section layout ──────────────────────

class _AvailableTab extends StatefulWidget {
  final List<ExtensionRepo> repos;
  final Map<int, List<ExtensionIndexEntry>> indexCache;
  final Set<int> loading;
  final List<ExtensionSource> installed;
  final void Function(ExtensionRepo) onFetch;
  final void Function(ExtensionIndexEntry, ExtensionRepo) onInstall;
  final VoidCallback onSeed;

  const _AvailableTab({
    required this.repos,
    required this.indexCache,
    required this.loading,
    required this.installed,
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

  /// O(1) lookup map: className → installed source.
  Map<String, ExtensionSource> _installedByClass() {
    final map = <String, ExtensionSource>{};
    for (final s in widget.installed) {
      if (s.className.isNotEmpty) map[s.className] = s;
    }
    return map;
  }

  ExtensionSource? _matchInstalled(
    _EntryWithRepo er,
    Map<String, ExtensionSource> byClass,
  ) {
    for (final s in er.entry.sources) {
      final className = s['className'] as String? ?? '';
      if (className.isEmpty) continue;
      final match = byClass[className];
      if (match != null) return match;
    }
    return null;
  }

  List<_AvailableRow> _buildRowsCached(Map<String, ExtensionSource> byClass) {
    final key = Object.hash(
      _query,
      widget.repos.length,
      widget.indexCache.length,
      widget.installed.length,
      _collapsedRepos.length,
    );
    if (_cachedRows != null && _rowsCacheKey == key) return _cachedRows!;
    _cachedRows = _buildRows(byClass);
    _rowsCacheKey = key;
    return _cachedRows!;
  }

  List<_AvailableRow> _buildRows(Map<String, ExtensionSource> byClass) {
    final allEntries = <_EntryWithRepo>[];
    for (final repo in widget.repos) {
      final entries = widget.indexCache[repo.id];
      if (entries == null) continue;
      for (final e in entries) {
        allEntries.add(_EntryWithRepo(entry: e, repo: repo));
      }
    }

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allEntries
        : allEntries
            .where((er) => er.entry.name.toLowerCase().contains(query))
            .toList(growable: false);

    final updateEntries = <_EntryWithRepo>[];
    final installedEntries = <_EntryWithRepo>[];
    final notInstalledEntries = <_EntryWithRepo>[];

    for (final er in filtered) {
      final match = _matchInstalled(er, byClass);
      if (match != null) {
        if (match.version != er.entry.version) {
          updateEntries.add(er);
        } else {
          installedEntries.add(er);
        }
      } else {
        if (!_allowedLanguages.contains(er.entry.lang.toLowerCase())) continue;
        notInstalledEntries.add(er);
      }
    }

    final rows = <_AvailableRow>[];

    if (updateEntries.isNotEmpty) {
      rows.add(const _AvailableRow.section('Update pending'));
      for (final er in updateEntries) {
        final match = _matchInstalled(er, byClass);
        rows.add(_AvailableRow.entry(
          er,
          installed: true,
          hasUpdate: true,
          installedVersion: match?.version,
        ));
      }
    }

    if (installedEntries.isNotEmpty) {
      rows.add(const _AvailableRow.section('Installed'));
      for (final er in installedEntries) {
        final match = _matchInstalled(er, byClass);
        rows.add(_AvailableRow.entry(
          er,
          installed: true,
          hasUpdate: false,
          installedVersion: match?.version,
        ));
      }
    }

    if (notInstalledEntries.isNotEmpty) {
      final groups = <int, List<_EntryWithRepo>>{};
      for (final er in notInstalledEntries) {
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
        rows.add(_AvailableRow.repoHeader(
          repoId: repoId,
          repoName: repo.name,
          count: group.length,
          expanded: expanded,
        ));
        if (expanded) {
          for (final er in group) {
            rows.add(_AvailableRow.entry(
              er,
              installed: false,
              hasUpdate: false,
            ));
          }
        }
      }
    }

    if (rows.isEmpty && allEntries.isNotEmpty) {
      rows.add(_AvailableRow.emptyMessage(
        query.isNotEmpty
            ? 'No extensions match "$_query"'
            : 'No extensions available',
      ));
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

    final hasAnyFetched =
        widget.repos.any((r) => widget.indexCache.containsKey(r.id));
    final byClass = _installedByClass();
    final rows = hasAnyFetched ? _buildRowsCached(byClass) : const <_AvailableRow>[];

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
                                Icon(Icons.search_off,
                                    size: 48, color: c.textTertiary),
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
  bool get isNsfw => sources.any(
    (s) => (s['nsfw'] as int? ?? 0) == 1,
  );
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
    final iconUrl = _deriveIconUrl(entry, context);
    final isNsfw = entry.isNsfw;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasUpdate ? c.accent.withAlpha(15) : c.surface,
        borderRadius: AppSpacing.brMd,
        border: Border.all(
          color: hasUpdate
              ? c.accent.withAlpha(51)
              : c.border,
        ),
      ),
      child: Row(
        children: [
          _buildIcon(iconUrl, c, size: 28),
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
                      ? 'Installed'
                      : 'Install',
            ),
          ),
        ],
      ),
    );
  }
}

/// Derive the icon URL for an [ExtensionIndexEntry] from the repo URL context.
String? _deriveIconUrl(ExtensionIndexEntry entry, BuildContext context) {
  // We don't have direct repo URL access here, but the icon path follows
  // mangayomi's pattern: "$repoUrl/icon/${pkg}.png". Try guacamoly's repo.
  return 'https://raw.githubusercontent.com/keiyoushi/extensions/repo/icon/${entry.pkg}.png';
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
          child: FloatingActionButton.extended(
            onPressed: onAdd,
            backgroundColor: c.accent,
            icon: const Icon(Icons.add),
            label: const Text('Add repo'),
          ),
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
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared icon widget for extension list tiles — loads the icon from [iconUrl]
/// with a fallback Material icon, matching mangayomi's extension_list_tile_widget.
///
/// [cacheWidth]/[cacheHeight] keep decoded bitmaps tiny so scrolling a long
/// extension list does not thrash memory (a major crash source on Android 15+).
Widget _buildIcon(String? iconUrl, KomaColors c, {double size = 37}) {
  if (iconUrl == null || iconUrl.isEmpty) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.extension_rounded, color: c.accent, size: size * 0.75),
    );
  }
  return _ExtensionNetworkIcon(iconUrl: iconUrl, colors: c, size: size);
}

class _ExtensionNetworkIcon extends StatelessWidget {
  final String iconUrl;
  final KomaColors colors;
  final double size;

  const _ExtensionNetworkIcon({
    required this.iconUrl,
    required this.colors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image(
          image: CustomExtendedNetworkImageProvider(iconUrl),
          fit: BoxFit.contain,
          width: size,
          height: size,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.extension_rounded,
              color: colors.accent,
              size: size * 0.75,
            ),
          ),
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
