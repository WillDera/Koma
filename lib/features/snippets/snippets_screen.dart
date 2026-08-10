import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/bookmark.dart';
import '../../core/models/snippet.dart';
import '../../core/models/snippet_collection.dart';
import '../../core/providers.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/aethelgard_fab.dart';
import '../../widgets/bookmark_card.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/highlight_color_picker.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/library_header.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/horizontal_tab_swipe.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/snippet_card.dart';
import '../../widgets/snippet_detail_sheet.dart';
import '../../widgets/tag_filter_bar.dart';
import '../../widgets/toast.dart';
import 'bookmarks_provider.dart';
import 'snippets_provider.dart';

class SnippetsScreen extends ConsumerStatefulWidget {
  const SnippetsScreen({super.key});

  @override
  ConsumerState<SnippetsScreen> createState() => _SnippetsScreenState();
}

class _SnippetsScreenState extends ConsumerState<SnippetsScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  int _tab = 0;
  String _searchQuery = '';
  /// Local book filter key: null = all books; otherwise bookId as string or
  /// `title:<sourceTitle>` for snippets without a bookId.
  String? _filterBookKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(snippetsProvider.notifier).loadSnippets();
      ref.read(bookmarksProvider.notifier).loadBookmarks();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Snippet> _applyLocalFilters(List<Snippet> items) {
    var out = items;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((s) {
        final hay = [
          s.text,
          s.note ?? '',
          s.sourceTitle ?? '',
          ...s.tags,
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    final key = _filterBookKey;
    if (key != null) {
      out = out.where((s) => _bookKeyFor(s) == key).toList();
    }
    return out;
  }

  String _bookKeyFor(Snippet s) {
    if (s.bookId != null) return 'id:${s.bookId}';
    final title = (s.sourceTitle ?? '').trim();
    if (title.isNotEmpty) return 'title:$title';
    return 'none';
  }

  String _bookLabelFor(Snippet s) {
    final title = (s.sourceTitle ?? '').trim();
    if (title.isNotEmpty) return title;
    if (s.bookId != null) return 'Book ${s.bookId}';
    return 'Untitled';
  }

  List<({String key, String label})> _uniqueBooks(List<Snippet> all) {
    final seen = <String>{};
    final out = <({String key, String label})>[];
    for (final s in all) {
      final key = _bookKeyFor(s);
      if (key == 'none' || !seen.add(key)) continue;
      out.add((key: key, label: _bookLabelFor(s)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final leftHanded = ref.watch(themeProvider).handMode == HandMode.left;
    final p = ref.watch(snippetsProvider);
    final bp = ref.watch(bookmarksProvider);
    final navClearance = MediaQuery.paddingOf(context).bottom + 84;
    return ScreenBackdrop(
      child: HorizontalTabSwipe(
        tabIndex: _tab,
        tabCount: 2,
        onTabChanged: _setTab,
        child: Stack(
          children: [
            SafeArea(bottom: false, child: _body(context, p, bp)),
            if (!p.selectionMode && _tab == 0)
              Positioned(
                left: leftHanded ? 20 : null,
                right: leftHanded ? null : 20,
                bottom: navClearance,
                child: AethelgardFab(
                  iconData: AppIcons.add,
                  onPressed: () => _createSnippet(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setTab(int v) {
    if (_tab == v) return;
    setState(() => _tab = v);
    if (v == 1) {
      ref.read(bookmarksProvider.notifier).loadBookmarks();
    }
  }

  Widget _body(BuildContext context, SnippetsState p, BookmarksState bp) {
    if (_tab == 1) {
      return _buildBookmarksTab(context, bp);
    }

    if (p.loading && p.snippets.isEmpty) return _loading();
    if (p.error != null) {
      return ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          const OneHandSpacer(),
          const LibraryHeader(title: 'Snippets', subtitle: '0 snippets'),
          _buildTabBar(),
          const SizedBox(height: 60),
          EmptyState(
            icon: AppIcons.alert,
            title: 'Could not load snippets',
            subtitle: p.error!,
            primaryActionLabel: 'Try again',
            onPrimaryAction: () =>
                ref.read(snippetsProvider.notifier).loadSnippets(),
          ),
        ],
      );
    }

    return _buildSnippetsTab(context, p);
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SegmentedControl<int>(
        segments: const {0: 'Snippets', 1: 'Bookmarks'},
        value: _tab,
        onChanged: _setTab,
      ),
    );
  }

  Widget _buildSnippetsTab(BuildContext context, SnippetsState p) {
    final base = p.snippets;
    final items = _applyLocalFilters(base);
    final hasFilter =
        p.filterTag != null ||
        p.filterCollectionId != null ||
        p.filterCollectionId == -1 ||
        _searchQuery.trim().isNotEmpty ||
        _filterBookKey != null;

    if (p.allSnippets.isEmpty && p.collections.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          const OneHandSpacer(),
          const LibraryHeader(title: 'Snippets', subtitle: '0 snippets'),
          _buildTabBar(),
          const SizedBox(height: 60),
          EmptyState(
            icon: AppIcons.bookmark,
            title: 'No snippets yet',
            subtitle: 'Highlight text while reading, or tap + to create one.',
            primaryActionLabel: 'New snippet',
            primaryActionIcon: AppIcons.add,
            onPrimaryAction: () => _createSnippet(context),
          ),
        ],
      );
    }

    final books = _uniqueBooks(p.allSnippets);

    return ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const OneHandSpacer(),
        _buildHeader(p, count: items.length),
        _buildTabBar(),
        if (!p.selectionMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search snippets...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
              ),
            ),
          ),
          _BookFilterChips(
            books: books,
            selectedKey: _filterBookKey,
            onSelected: (key) => setState(() => _filterBookKey = key),
          ),
          _CollectionFilterBar(
            collections: p.collections,
            selectedId: p.filterCollectionId,
            onSelected: ref.read(snippetsProvider.notifier).setFilterCollection,
          ),
          if (p.allTags.isNotEmpty)
            TagFilterBar(
              tags: p.allTags,
              selected: p.filterTag,
              onChanged: ref.read(snippetsProvider.notifier).setFilterTag,
            ),
        ],
        if (items.isEmpty)
          SizedBox(
            height: 200,
            child: EmptyState(
              icon: AppIcons.note,
              title: hasFilter ? 'No matching snippets' : 'No snippets yet',
              subtitle: hasFilter
                  ? 'Try a different filter or clear search.'
                  : 'Highlight text while reading, or tap + to create one.',
            ),
          )
        else ...[
          SectionLabel(title: _sectionTitle(p), meta: '${items.length}'),
          ...items.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: StaggeredEntrance(
                index: entry.$1 + 1,
                child: SnippetCard(
                  snippet: entry.$2,
                  selected:
                      p.selectionMode && p.selectedIds.contains(entry.$2.id),
                  selectionMode: p.selectionMode,
                  onTap: () {
                    if (p.selectionMode) {
                      ref
                          .read(snippetsProvider.notifier)
                          .toggleSelection(entry.$2.id);
                    } else {
                      _editSnippet(context, entry.$2, p);
                    }
                  },
                  onLongPress: () {
                    if (!p.selectionMode) {
                      ref
                          .read(snippetsProvider.notifier)
                          .toggleSelection(entry.$2.id);
                    }
                  },
                  onOpenSource: entry.$2.bookId != null
                      ? () => _openBookReader(
                          context,
                          entry.$2.bookId!,
                          chapterId: entry.$2.chapterId,
                          scrollOffset: entry.$2.scrollPosition,
                          startOffset: entry.$2.startOffset,
                          endOffset: entry.$2.endOffset,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  String _sectionTitle(SnippetsState p) {
    final colId = p.filterCollectionId;
    if (colId == -1) return 'All snippets';
    if (colId == null) return 'Uncollected';
    final col = p.collections.firstWhereOrNull((c) => c.id == colId);
    return col?.name ?? 'Collection';
  }

  Widget _buildHeader(SnippetsState p, {required int count}) {
    final sn = ref.read(snippetsProvider.notifier);
    if (p.selectionMode) {
      return LibraryHeader(
        title: '${p.selectedIds.length} selected',
        actions: [
          IconButtonRound(
            icon: Icons.select_all_rounded,
            size: 36,
            variant: IconButtonVariant.tonal,
            iconColor: context.colors.textSecondary,
            tooltip: 'Select All',
            onPressed:
                p.selectedIds.length == p.snippets.length &&
                    p.snippets.isNotEmpty
                ? sn.clearSelection
                : sn.selectAll,
          ),
          const SizedBox(width: 4),
          IconButtonRound(
            icon: Icons.swap_horiz_rounded,
            size: 36,
            variant: IconButtonVariant.tonal,
            iconColor: context.colors.textSecondary,
            tooltip: 'Inverse',
            onPressed: sn.inverseSelection,
          ),
          const SizedBox(width: 4),
          IconButtonRound(
            icon: Icons.folder_open_outlined,
            size: 36,
            variant: IconButtonVariant.tonal,
            iconColor: context.colors.textSecondary,
            tooltip: 'Group into collection',
            onPressed: () => _groupSelected(context, p),
          ),
          const SizedBox(width: 4),
          IconButtonRound(
            icon: Icons.delete_outline,
            size: 36,
            variant: IconButtonVariant.tonal,
            iconColor: const Color(0xFFC44C4C),
            tooltip: 'Delete selected',
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: 4),
          IconButtonRound(
            icon: Icons.close,
            size: 36,
            variant: IconButtonVariant.tonal,
            iconColor: context.colors.textSecondary,
            tooltip: 'Done',
            onPressed: sn.clearSelection,
          ),
        ],
      );
    }
    return LibraryHeader(
      title: 'Snippets',
      subtitle: '$count snippet${count == 1 ? '' : 's'}',
      actions: [
        IconButtonRound(
          icon: Icons.checklist_rtl_rounded,
          size: 36,
          variant: IconButtonVariant.tonal,
          iconColor: context.colors.textSecondary,
          tooltip: 'Select',
          onPressed: () => sn.selectAll(),
        ),
      ],
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const OneHandSpacer(),
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Skeleton(
              height: 180,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
      ],
    );
  }

  void _openBookReader(
    BuildContext context,
    int bookId, {
    int? chapterId,
    double? scrollOffset,
    int? startOffset,
    int? endOffset,
  }) {
    context.pushNamed(
      Routes.reader,
      extra: (
        bookId: bookId,
        snippetChapterId: chapterId,
        snippetScrollOffset: scrollOffset,
        snippetStartOffset: startOffset,
        snippetEndOffset: endOffset,
      ),
    );
  }

  void _createSnippet(BuildContext context) {
    SnippetDetailSheet.show(
      context,
      creating: true,
      onSave: (s) async {
        try {
          await ref
              .read(snippetsProvider.notifier)
              .createSnippet(
                text: s.text,
                note: s.note,
                sourceTitle: s.sourceTitle,
                color: s.color,
                tags: s.tags,
              );
          if (context.mounted) {
            StashToast.show(
              context,
              message: 'Snippet saved',
              icon: Icons.check,
            );
          }
        } catch (e) {
          if (context.mounted) {
            StashToast.show(
              context,
              message: 'Failed: $e',
              icon: Icons.error_outline,
            );
          }
        }
      },
    );
  }

  void _editSnippet(BuildContext context, Snippet snippet, SnippetsState p) {
    final sn = ref.read(snippetsProvider.notifier);
    SnippetDetailSheet.show(
      context,
      snippet: snippet,
      onSave: (s) async {
        await sn.updateSnippet(s);
        if (context.mounted) {
          StashToast.show(
            context,
            message: 'Snippet updated',
            icon: Icons.check,
          );
        }
      },
      onDelete: (id) async {
        await sn.deleteSnippet(id);
        if (context.mounted) {
          StashToast.show(
            context,
            message: 'Snippet deleted',
            icon: Icons.check,
          );
        }
      },
    );
  }

  Future<void> _confirmDelete() async {
    final p = ref.read(snippetsProvider);
    final sn = ref.read(snippetsProvider.notifier);
    final ctx = context;
    final confirmed = await StashDialog.show<bool>(
      ctx,
      title: 'Delete ${p.selectedIds.length} snippets?',
      content: 'This cannot be undone.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: ctx.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Color(0xFFC44C4C)),
          ),
        ),
      ],
    );
    if (confirmed == true) {
      await sn.deleteSelected();
      if (ctx.mounted) {
        StashToast.show(ctx, message: 'Snippets deleted', icon: Icons.check);
      }
    }
  }

  Future<void> _groupSelected(BuildContext context, SnippetsState p) async {
    final sn = ref.read(snippetsProvider.notifier);
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: Icon(Icons.folder_off_outlined, color: c.secondary),
                title: Text('Ungrouped', style: TextStyle(color: c.secondary)),
                onTap: () => Navigator.pop(ctx, null),
              ),
              if (p.collections.isNotEmpty) const Divider(height: 1),
              ...p.collections.map((col) {
                return ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: _parseColor(col.color),
                  ),
                  title: Text(col.name),
                  onTap: () => Navigator.pop(ctx, col.id),
                );
              }),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: c.primary),
                title: Text(
                  'New collection',
                  style: TextStyle(color: c.primary),
                ),
                trailing: Icon(Icons.chevron_right, color: c.primary),
                onTap: () async {
                  final nameController = TextEditingController();
                  String selectedColor = '#FFD700';
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (dialogCtx) {
                      final dc = Theme.of(dialogCtx).colorScheme;
                      return StatefulBuilder(
                        builder: (ctx2, setState2) => AlertDialog(
                          title: const Text('New collection'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  hintText: 'My collection',
                                ),
                                autofocus: true,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Accent colour',
                                style: TextStyle(
                                  color: dc.secondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              HighlightColorPicker(
                                colors: HighlightColorPicker.palette,
                                selected: selectedColor,
                                onChanged: (c) {
                                  setState2(() => selectedColor = c);
                                },
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: dc.secondary),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  const keyToHex = <String, String>{
                    'yellow': '#FFE8A8',
                    'blue': '#C8D8FF',
                    'pink': '#FFD4DC',
                    'green': '#C8E6C9',
                  };
                  if (confirmed == true &&
                      nameController.text.trim().isNotEmpty) {
                    final hex = keyToHex[selectedColor] ?? '#FFE8A8';
                    final id = await sn.createCollection(
                      nameController.text.trim(),
                      color: hex,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx, id);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );

    if (result == null) {
      await sn.moveSnippetsToCollection(p.selectedIds.toList(), null);
    } else if (result > 0) {
      await sn.moveSnippetsToCollection(p.selectedIds.toList(), result);
    }
    if (context.mounted) {
      sn.clearSelection();
    }
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length < 6) return const Color(0xFFFFE8A8);
    final value = int.tryParse(cleaned.substring(0, 6), radix: 16);
    if (value == null) return const Color(0xFFFFE8A8);
    return Color(value + 0xFF000000);
  }

  Widget _buildBookmarksTab(BuildContext context, BookmarksState bp) {
    final bookmarks = bp.bookmarks;
    return ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.zero,
      children: [
        const OneHandSpacer(),
        LibraryHeader(
          title: 'Bookmarks',
          subtitle: '${bookmarks.length} bookmark${bookmarks.length == 1 ? '' : 's'}',
        ),
        _buildTabBar(),
        if (bp.loading && bookmarks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (bookmarks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: EmptyState(
              icon: AppIcons.bookmark,
              title: 'No bookmarks yet',
              subtitle: 'Tap the bookmark icon while reading to save a page.',
            ),
          )
        else
          ...bookmarks.map(
            (b) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: BookmarkCard(
                bookmark: b,
                onTap: () => _openBookmark(context, b),
                onDelete: () => _confirmDeleteBookmark(context, b.id),
              ),
            ),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _openBookmark(BuildContext context, Bookmark bookmark) async {
    if (bookmark.bookId <= 0) return;
    final repos = ref.read(repositoriesProvider);
    final chapter = await repos.manga.getMangaChapter(bookmark.chapterId);
    if (chapter == null || !context.mounted) return;
    // Bookmarks store manga ids in [Bookmark.bookId] — look up manga, not ebook.
    final manga = await repos.manga.getMangaById(bookmark.bookId);
    if (manga == null || !context.mounted) {
      if (context.mounted) {
        StashToast.show(
          context,
          message: 'Manga no longer in library',
          icon: Icons.error_outline,
        );
      }
      return;
    }
    context.pushNamed(
      Routes.mangaReader,
      extra: (
        mangaId: bookmark.bookId,
        sourceId: manga.sourceId,
        mangaUrl: manga.url,
        chapterUrl: chapter.url,
        chapterName: chapter.name,
        pageNumber: bookmark.pageNumber,
      ),
    );
  }

  Future<void> _confirmDeleteBookmark(BuildContext context, int id) async {
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Remove bookmark?',
      content: 'This cannot be undone.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Remove',
            style: TextStyle(color: Color(0xFFC44C4C)),
          ),
        ),
      ],
    );
    if (confirmed == true && context.mounted) {
      await ref.read(bookmarksProvider.notifier).deleteBookmark(id);
      if (context.mounted) {
        StashToast.show(
          context,
          message: 'Bookmark removed',
          icon: Icons.check,
        );
      }
    }
  }
}

Color _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length < 6) return const Color(0xFFFFE8A8);
  final value = int.tryParse(cleaned.substring(0, 6), radix: 16);
  if (value == null) return const Color(0xFFFFE8A8);
  return Color(value + 0xFF000000);
}

class _BookFilterChips extends StatelessWidget {
  final List<({String key, String label})> books;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  const _BookFilterChips({
    required this.books,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: 'All Books',
              selected: selectedKey == null,
              color: c.accent,
              filled: true,
              onSelected: () => onSelected(null),
            ),
            for (final book in books) ...[
              const SizedBox(width: 8),
              _Chip(
                label: book.label,
                selected: selectedKey == book.key,
                color: c.accent,
                filled: true,
                onSelected: () {
                  onSelected(selectedKey == book.key ? null : book.key);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionFilterBar extends StatelessWidget {
  final List<SnippetCollection> collections;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _CollectionFilterBar({
    required this.collections,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chips = <Widget>[
      _Chip(
        label: 'All',
        selected: selectedId == -1,
        color: c.accent,
        onSelected: () => onSelected(-1),
      ),
      const SizedBox(width: 8),
      _Chip(
        label: 'Uncollected',
        selected: selectedId == null,
        color: c.textSecondary,
        onSelected: () => onSelected(null),
      ),
    ];
    for (final col in collections) {
      chips.add(const SizedBox(width: 8));
      chips.add(
        _Chip(
          label: col.name,
          selected: selectedId == col.id,
          color: _parseHexColor(col.color),
          onSelected: () {
            if (selectedId == col.id) {
              onSelected(null);
            } else {
              onSelected(col.id);
            }
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onSelected;
  final bool filled;

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color bg;
    final Color fg;
    Border? border;
    if (filled && selected) {
      bg = color;
      fg = c.onAccent;
      border = null;
    } else if (selected) {
      bg = color.withValues(alpha: 0.18);
      fg = color;
      border = Border.all(color: color.withValues(alpha: 0.6));
    } else {
      bg = c.surfaceMuted;
      fg = c.textSecondary;
      border = null;
    }
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        constraints: const BoxConstraints(maxWidth: 140),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
