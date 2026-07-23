import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/extension_repo.dart';
import '../../core/models/extension_source.dart';
import '../../core/services/database_service.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import 'source_browse_screen.dart';

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
      setState(() {
        _indexCache[repo.id] = entries;
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
      await _mgr.install(entry, repoUrl: repo.url);
      messenger.showSnackBar(
        SnackBar(content: Text('Installed ${entry.name}')),
      );
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
                Icon(Icons.extension, color: c.accent),
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

// ─── Available tab ──────────────────────────────────────────────────────
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

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
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
    final installedIds = widget.installed.map((s) => s.id).toSet();

    // pony tail: filter by en/all lang only
    bool _langOk(ExtensionIndexEntry e) {
      final l = e.lang.toLowerCase();
      return l == 'en' || l == 'all';
    }

    bool _queryOk(ExtensionIndexEntry e) =>
        _query.isEmpty || e.name.toLowerCase().contains(_query.toLowerCase());

    final hasAnyFetched =
        widget.repos.any((r) => widget.indexCache.containsKey(r.id));

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
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.brMd,
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final repo in widget.repos) ...[
                _RepoHeader(
                  repo: repo,
                  loading: widget.loading.contains(repo.id),
                  onFetch: () => widget.onFetch(repo),
                ),
                const SizedBox(height: 8),
                ...?widget.indexCache[repo.id]
                    ?.where((e) => _langOk(e) && _queryOk(e))
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ExtensionRow(
                          entry: e,
                          installed: installedIds.contains(_entryId(e)),
                          onInstall: () => widget.onInstall(e, repo),
                        ),
                      ),
                    ),
                if (widget.indexCache[repo.id] != null &&
                    widget.indexCache[repo.id]!
                        .where((e) => _langOk(e) && _queryOk(e))
                        .isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _query.isEmpty
                          ? 'No en/all extensions in this repo'
                          : 'No matches',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _entryId(ExtensionIndexEntry e) {
  if (e.sources.isNotEmpty && e.sources.first['id'] != null) {
    return e.sources.first['id'].toString();
  }
  return e.pkg;
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
  final VoidCallback onInstall;

  const _ExtensionRow({
    required this.entry,
    required this.installed,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppSpacing.brMd,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            installed ? Icons.check_circle : Icons.extension_outlined,
            color: installed ? c.accent : c.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'v${entry.version} · ${entry.lang} · ${entry.sources.length} source${entry.sources.length == 1 ? '' : 's'}',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: installed ? null : onInstall,
            child: Text(installed ? 'Installed' : 'Install'),
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
