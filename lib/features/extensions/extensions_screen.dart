import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/extension_repo.dart';
import '../../core/models/extension_source.dart';
import '../../core/services/database_service.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/language.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import 'extension_detail_screen.dart';

const _keiyoushiDefaultRepoUrl =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
const _keiyoushiDefaultRepoName = 'Keiyoushi (official)';

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen>
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
    final db = context.read<DatabaseService>();
    _mgr = ExtensionManager(db, KeiyoushiService());
    _refresh();
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
    try {
      final sources = await _mgr.install(entry, repoUrl: repo.url);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Installed ${sources.length} source${sources.length == 1 ? '' : 's'} from ${entry.name}',
          ),
        ),
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
                      builder: (_) => ExtensionDetailScreen(
                        source: src,
                        onUninstall: () => _uninstall(src),
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

class _AvailableTabState extends State<_AvailableTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showNsfw = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    // Auto-fetch repos that haven't been fetched yet (mangayomi pattern)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final repo in widget.repos) {
        if (!widget.indexCache.containsKey(repo.id)) {
          widget.onFetch(repo);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

    // Build a flat list of all index entries across repos
    final allEntries = <_EntryWithRepo>[];
    for (final repo in widget.repos) {
      final entries = widget.indexCache[repo.id];
      if (entries == null) continue;
      for (final e in entries) {
        allEntries.add(_EntryWithRepo(entry: e, repo: repo));
      }
    }

    // Filter by query
    var filtered = _query.isEmpty
        ? allEntries
        : allEntries
            .where((er) =>
                er.entry.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    // Filter by NSFW
    if (!_showNsfw) {
      filtered = filtered.where((er) => !er.entry.isNsfw).toList();
    }

    // Sort entries: updates first, then installed, then not-installed by lang
    final updateEntries = <_EntryWithRepo>[];
    final installedEntries = <_EntryWithRepo>[];
    final notInstalledEntries = <_EntryWithRepo>[];

    for (final er in filtered) {
      if (_hasUpdateAvailable(er, widget.installed)) {
        updateEntries.add(er);
      } else if (_hasInstalled(er, widget.installed)) {
        installedEntries.add(er);
      } else {
        notInstalledEntries.add(er);
      }
    }

    return Column(
      children: [
        if (hasAnyFetched)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search extensions…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchCtrl.clear(),
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
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _showNsfw ? Icons.eighteen_up_rating : Icons.family_restroom,
                    color: _showNsfw ? c.accent : c.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showNsfw = !_showNsfw),
                  tooltip: _showNsfw ? 'Hide NSFW' : 'Show NSFW',
                ),
              ],
            ),
          ),
        Expanded(
          child: allEntries.isEmpty
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
              // ── Updates section ──
              if (updateEntries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'Update pending',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                ...updateEntries.map(
                  (er) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _ExtensionRow(
                      entry: er.entry,
                      installed: true,
                      hasUpdate: true,
                      installedVersion:
                          _installedVersionForEntry(er, widget.installed),
                      onInstall: () => widget.onInstall(er.entry, er.repo),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Installed section ──
              if (installedEntries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Installed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                ...installedEntries.map(
                  (er) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _ExtensionRow(
                      entry: er.entry,
                      installed: true,
                      hasUpdate: false,
                      installedVersion:
                          _installedVersionForEntry(er, widget.installed),
                      onInstall: () => widget.onInstall(er.entry, er.repo),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Not installed section (grouped by language) ──
              if (notInstalledEntries.isNotEmpty) ...[
                ..._buildLanguageGroups(notInstalledEntries, c),
              ],
              // Show a message when nothing matches the current filters
              if (updateEntries.isEmpty &&
                  installedEntries.isEmpty &&
                  notInstalledEntries.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: c.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No extensions match "$_query"'
                              : !_showNsfw
                                  ? 'All extensions are NSFW. Enable NSFW to see them.'
                                  : 'No extensions available',
                          style: TextStyle(color: c.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLanguageGroups(
    List<_EntryWithRepo> entries,
    KomaColors c,
  ) {
    // Group by language code
    final groups = <String, List<_EntryWithRepo>>{};
    for (final er in entries) {
      final lang = er.entry.lang.toLowerCase();
      groups.putIfAbsent(lang, () => []);
      groups[lang]!.add(er);
    }

    // Sort language keys by their full name
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => completeLanguageName(a).compareTo(completeLanguageName(b)));

    final widgets = <Widget>[];
    for (final langKey in sortedKeys) {
      final langName = completeLanguageName(langKey);
      final group = groups[langKey]!;
      // Sort entries by name within the group
      group.sort((a, b) => a.entry.name.compareTo(b.entry.name));

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            langName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: c.textPrimary,
            ),
          ),
        ),
      );
      for (final er in group) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ExtensionRow(
              entry: er.entry,
              installed: false,
              hasUpdate: false,
              onInstall: () => widget.onInstall(er.entry, er.repo),
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  bool _hasInstalled(_EntryWithRepo er, List<ExtensionSource> installed) {
    for (final s in er.entry.sources) {
      final sourceId = s['id']?.toString() ?? er.entry.pkg;
      if (installed.any((isrc) => isrc.id == 'mihon-$sourceId')) return true;
    }
    return false;
  }

  bool _hasUpdateAvailable(_EntryWithRepo er, List<ExtensionSource> installed) {
    // Check if any source from this entry is installed AND has a version that
    // differs from the index entry's version (meaning an update is available).
    for (final s in er.entry.sources) {
      final sourceId = s['id']?.toString() ?? er.entry.pkg;
      final match = installed.firstWhere(
        (isrc) => isrc.id == 'mihon-$sourceId',
        orElse: () => ExtensionSource(
          id: '',
          name: '',
          version: '',
          lang: '',
          apkPath: '',
          className: '',
        ),
      );
      // Only report update if the source is actually installed AND versions differ
      if (match.id.isNotEmpty && match.version != er.entry.version) {
        return true;
      }
    }
    return false;
  }

  String? _installedVersionForEntry(
    _EntryWithRepo er,
    List<ExtensionSource> installed,
  ) {
    for (final s in er.entry.sources) {
      final sourceId = s['id']?.toString() ?? er.entry.pkg;
      final match = installed.firstWhere(
        (isrc) => isrc.id == 'mihon-$sourceId',
        orElse: () => ExtensionSource(
          id: '',
          name: '',
          version: '',
          lang: '',
          apkPath: '',
          className: '',
        ),
      );
      if (match.id.isNotEmpty) return match.version;
    }
    return null;
  }
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
Widget _buildIcon(String? iconUrl, KomaColors c, {double size = 37}) {
  if (iconUrl == null || iconUrl.isEmpty) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.extension_rounded, color: c.accent, size: size * 0.75),
    );
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
      child: Image.network(
        iconUrl,
        fit: BoxFit.contain,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.extension_rounded, color: c.accent, size: size * 0.75),
        ),
      ),
    ),
  );
}
