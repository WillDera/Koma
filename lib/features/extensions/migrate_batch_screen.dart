import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/local_cbz_source.dart';
import '../../core/services/migrate_suggestion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/screen_chrome.dart';
import 'migrate_search_screen.dart';
import 'migrate_suggestion_provider.dart';

/// Batch migration entry: library manga list with per-title migrate action.
/// Optionally scans for sources with more chapters.
class MigrateBatchScreen extends ConsumerStatefulWidget {
  const MigrateBatchScreen({super.key});

  @override
  ConsumerState<MigrateBatchScreen> createState() => _MigrateBatchScreenState();
}

class _MigrateBatchScreenState extends ConsumerState<MigrateBatchScreen> {
  List<Manga> _library = [];
  Map<String, String> _sourceNames = {};
  final Map<int, MigrateSuggestion> _suggestions = {};
  bool _loading = true;
  bool _scanning = false;
  bool _busy = false;
  int _scanDone = 0;
  int _scanTotal = 0;
  int _scanGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repos = ref.read(repositoriesProvider);
    final all = await repos.manga.getMangasInLibrary();
    final installed = await repos.extensions.getInstalledExtensions();
    final names = <String, String>{};
    for (final s in installed) {
      if (s.name.isEmpty) continue;
      if (s.sourceId.isNotEmpty) names[s.sourceId] = s.name;
      if (s.id.isNotEmpty) names[s.id] = s.name;
    }
    if (!mounted) return;
    setState(() {
      _library = all;
      _sourceNames = names;
      _loading = false;
    });
  }

  String _sourceLabel(Manga manga) {
    final id = manga.sourceId;
    if (id.isEmpty) return 'Unknown source';
    return _sourceNames[id] ?? id;
  }

  Future<void> _scanSuggestions() async {
    if (_scanning) return;
    final gen = ++_scanGen;
    final service = ref.read(migrateSuggestionServiceProvider);
    final candidates = [
      for (final m in _library)
        if (!LocalCbzSource.isLocal(m.sourceId)) m,
    ];
    setState(() {
      _scanning = true;
      _scanDone = 0;
      _scanTotal = candidates.length;
      _suggestions.clear();
    });

    for (final manga in candidates) {
      if (!mounted || gen != _scanGen) return;
      try {
        final sug = await service.findBetterSource(manga);
        if (sug != null && mounted && gen == _scanGen) {
          setState(() => _suggestions[manga.id] = sug);
        }
      } catch (_) {
        // best-effort
      }
      if (!mounted || gen != _scanGen) return;
      setState(() => _scanDone++);
    }

    if (!mounted || gen != _scanGen) return;
    setState(() => _scanning = false);
  }

  Future<void> _migrate(Manga manga, {MigrateSuggestion? suggestion}) async {
    if (_busy) return;
    if (suggestion != null) {
      try {
        final target = await confirmAndMigrate(
          context: context,
          ref: ref,
          currentMangaId: manga.id,
          currentTitle: manga.name,
          targetSourceId: suggestion.targetSourceId,
          targetSourceName: suggestion.targetSourceName,
          targetUrl: suggestion.targetUrl,
          targetTitle: suggestion.targetTitle,
          targetMemo: suggestion.targetMemo,
          onConfirmed: () {
            if (mounted) setState(() => _busy = true);
          },
        );
        if (target != null && mounted) {
          _suggestions.remove(manga.id);
          await _load();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migrate failed: $e')),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final target = await Navigator.of(context).push<Manga>(
      scaleFadeRoute(
        MigrateSearchScreen(
          currentMangaId: manga.id,
          currentTitle: manga.name,
          excludeSourceId: manga.sourceId,
        ),
      ),
    );
    if (target != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ScreenBackdrop(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Batch migrate'),
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              foregroundColor: c.textPrimary,
              actions: [
                if (!_loading)
                  TextButton(
                    onPressed: _scanning || _busy ? null : _scanSuggestions,
                    child: Text(
                      _scanning
                          ? 'Scanning $_scanDone/$_scanTotal'
                          : 'Find better sources',
                      style: TextStyle(color: c.accent),
                    ),
                  ),
              ],
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _library.isEmpty
                ? Center(
                    child: Text(
                      'No library manga to migrate',
                      style: TextStyle(color: c.textTertiary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _library.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: c.border, height: 1),
                    itemBuilder: (context, i) {
                      final m = _library[i];
                      final sug = _suggestions[m.id];
                      return ListTile(
                        title: Text(
                          m.name,
                          style: TextStyle(color: c.textPrimary),
                        ),
                        subtitle: Text(
                          sug != null
                              ? '${_sourceLabel(m)} · ${sug.message}'
                              : _sourceLabel(m),
                          style: TextStyle(
                            color: sug != null ? c.accent : c.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _migrate(m, suggestion: sug),
                          child: Text(sug != null ? 'Migrate' : 'Search'),
                        ),
                      );
                    },
                  ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x99000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Migrating…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
