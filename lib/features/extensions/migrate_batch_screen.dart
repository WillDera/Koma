import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/screen_chrome.dart';
import 'migrate_search_screen.dart';

/// Batch migration entry: library manga list with per-title migrate action.
class MigrateBatchScreen extends ConsumerStatefulWidget {
  const MigrateBatchScreen({super.key});

  @override
  ConsumerState<MigrateBatchScreen> createState() => _MigrateBatchScreenState();
}

class _MigrateBatchScreenState extends ConsumerState<MigrateBatchScreen> {
  List<Manga> _library = [];
  Map<String, String> _sourceNames = {};
  bool _loading = true;

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

  Future<void> _migrate(Manga manga) async {
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Batch migrate'),
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: c.textPrimary,
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
                  return ListTile(
                    title:
                        Text(m.name, style: TextStyle(color: c.textPrimary)),
                    subtitle: Text(
                      _sourceLabel(m),
                      style: TextStyle(color: c.textTertiary, fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () => _migrate(m),
                      child: const Text('Migrate'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
