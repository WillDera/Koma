import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/migrate_manga_use_case.dart';
import '../../theme/app_theme.dart';
import 'global_search_provider.dart';
import 'global_search_widgets.dart';

/// Mihon-style migrate search: Global Search over other sources, then confirm.
class MigrateSearchScreen extends ConsumerStatefulWidget {
  const MigrateSearchScreen({
    super.key,
    required this.currentMangaId,
    required this.currentTitle,
    required this.excludeSourceId,
  });

  final int currentMangaId;
  final String currentTitle;
  final String excludeSourceId;

  @override
  ConsumerState<MigrateSearchScreen> createState() =>
      _MigrateSearchScreenState();
}

class _MigrateSearchScreenState extends ConsumerState<MigrateSearchScreen> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentTitle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(globalSearchProvider.notifier);
      notifier.setExcludeSourceId(widget.excludeSourceId);
      notifier.search(widget.currentTitle);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(globalSearchProvider.notifier).search(_ctrl.text.trim());
  }

  Future<void> _onMangaTap(
    GlobalSearchSourceItem item,
    Map<String, dynamic> manga,
  ) async {
    if (_busy) return;
    final url = (manga['url'] as String? ?? '').trim();
    if (url.isEmpty) return;
    final title = manga['title'] as String? ?? widget.currentTitle;
    final memo = manga['memo'] as String?;

    final choice = await showDialog<_MigrateChoice>(
      context: context,
      builder: (ctx) => _MigrateConfirmDialog(
        currentTitle: widget.currentTitle,
        targetTitle: title,
        targetSourceName: item.source.name,
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repos = ref.read(repositoriesProvider);
      final current = await repos.manga.getMangaById(widget.currentMangaId);
      if (current == null) {
        throw StateError('Current manga not found');
      }
      final useCase = MigrateMangaUseCase(
        repositories: repos,
        dispatch: ref.read(extensionServiceProvider),
        keiyoushi: ref.read(keiyoushiServiceProvider),
      );
      final target = await useCase.invoke(
        current: current,
        targetSourceId: item.source.sourceId,
        targetUrl: url,
        targetTitle: title,
        targetMemo: memo,
        replace: choice.replace,
        flags: MigrationFlags(
          chapters: choice.chapters,
          removeDownloads: choice.removeDownloads,
          categories: choice.categories,
          notes: choice.notes,
          customCover: choice.customCover,
        ),
      );
      if (!mounted) return;
      ref.read(libraryProvider.notifier).loadBooks();
      ref.read(globalSearchProvider.notifier).setExcludeSourceId(null);
      Navigator.of(context).pop(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migrate failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(globalSearchProvider);
    final notifier = ref.read(globalSearchProvider.notifier);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(globalSearchProvider.notifier).setExcludeSourceId(null);
        }
      },
      child: Stack(
      children: [
        Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.bg,
            iconTheme: IconThemeData(color: c.textPrimary),
            title: TextField(
              controller: _ctrl,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: notifier.setQuery,
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Migrate search',
                hintStyle: TextStyle(color: c.textSecondary),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: c.textSecondary),
                  onPressed: _submit,
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(state.searching ? 52 : 48),
              child: const GlobalSearchFilterBar(),
            ),
          ),
          body: GlobalSearchResultsList(
            onMangaTap: _onMangaTap,
          ),
        ),
        if (_busy)
          const ColoredBox(
            color: Color(0x99000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
    );
  }
}

class _MigrateChoice {
  const _MigrateChoice({
    required this.replace,
    required this.chapters,
    required this.removeDownloads,
    required this.categories,
    required this.notes,
    required this.customCover,
  });

  final bool replace;
  final bool chapters;
  final bool removeDownloads;
  final bool categories;
  final bool notes;
  final bool customCover;
}

class _MigrateConfirmDialog extends StatefulWidget {
  const _MigrateConfirmDialog({
    required this.currentTitle,
    required this.targetTitle,
    required this.targetSourceName,
  });

  final String currentTitle;
  final String targetTitle;
  final String targetSourceName;

  @override
  State<_MigrateConfirmDialog> createState() => _MigrateConfirmDialogState();
}

class _MigrateConfirmDialogState extends State<_MigrateConfirmDialog> {
  bool _chapters = true;
  bool _removeDownloads = true;
  bool _categories = true;
  bool _notes = true;
  bool _customCover = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Migrate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From “${widget.currentTitle}” → “${widget.targetTitle}” '
              '(${widget.targetSourceName})',
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chapters'),
              subtitle: const Text('Transfer read progress by chapter number'),
              value: _chapters,
              onChanged: (v) => setState(() => _chapters = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remove downloads'),
              subtitle: const Text('Delete downloads on the old source entry'),
              value: _removeDownloads,
              onChanged: (v) => setState(() => _removeDownloads = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Categories'),
              subtitle: const Text('Copy library category membership'),
              value: _categories,
              onChanged: (v) => setState(() => _categories = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notes'),
              subtitle: const Text('Copy user notes'),
              value: _notes,
              onChanged: (v) => setState(() => _notes = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom cover'),
              subtitle: const Text('Copy local cover override if set'),
              value: _customCover,
              onChanged: (v) => setState(() => _customCover = v ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _MigrateChoice(
              replace: false,
              chapters: _chapters,
              removeDownloads: _removeDownloads,
              categories: _categories,
              notes: _notes,
              customCover: _customCover,
            ),
          ),
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MigrateChoice(
              replace: true,
              chapters: _chapters,
              removeDownloads: _removeDownloads,
              categories: _categories,
              notes: _notes,
              customCover: _customCover,
            ),
          ),
          child: const Text('Migrate'),
        ),
      ],
    );
  }
}
