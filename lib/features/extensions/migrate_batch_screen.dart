import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import 'migrate_search_screen.dart';

/// Batch migration entry: library manga list with per-title migrate action.
class MigrateBatchScreen extends ConsumerStatefulWidget {
  const MigrateBatchScreen({super.key});

  @override
  ConsumerState<MigrateBatchScreen> createState() => _MigrateBatchScreenState();
}

class _MigrateBatchScreenState extends ConsumerState<MigrateBatchScreen> {
  List<Manga> _library = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repos = ref.read(repositoriesProvider);
    final all = await repos.manga.getMangasInLibrary();
    if (!mounted) return;
    setState(() {
      _library = all;
      _loading = false;
    });
  }

  Future<void> _migrate(Manga manga) async {
    final target = await Navigator.of(context).push<Manga>(
      MaterialPageRoute(
        builder: (_) => MigrateSearchScreen(
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
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Batch migrate'),
        backgroundColor: c.bg,
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
              separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
              itemBuilder: (context, i) {
                final m = _library[i];
                return ListTile(
                  title: Text(m.name, style: TextStyle(color: c.textPrimary)),
                  subtitle: Text(
                    m.sourceId,
                    style: TextStyle(color: c.textTertiary, fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _migrate(m),
                    child: const Text('Migrate'),
                  ),
                );
              },
            ),
    );
  }
}
