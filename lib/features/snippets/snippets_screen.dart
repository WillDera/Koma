import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/bookmark.dart';
import '../../core/models/snippet.dart';
import '../../core/models/snippet_collection.dart';
import '../../core/providers.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/bookmark_card.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/highlight_color_picker.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/library_header.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';
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
  double _scrollProgress = 0;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(snippetsProvider.notifier).loadSnippets();
      ref.read(bookmarksProvider.notifier).loadBookmarks();
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final p = max <= 0 ? 0.0 : (_scrollCtrl.offset / max).clamp(0.0, 1.0);
    if ((p - _scrollProgress).abs() > 0.01) {
      setState(() => _scrollProgress = p);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _oneHand => ref.watch(themeProvider).oneHandMode;

  @override
  Widget build(BuildContext context) {
    final leftHanded = ref.watch(themeProvider).handMode == HandMode.left;
    final p = ref.watch(snippetsProvider);
    final bp = ref.watch(bookmarksProvider);
    final navClearance = MediaQuery.paddingOf(context).bottom + 84;
    return ScreenBackdrop(
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _body(context, p, bp),
          ),
          if (!p.selectionMode && _tab == 0)
            Positioned(
              left: leftHanded ? 20 : null,
              right: leftHanded ? null : 20,
              bottom: navClearance,
              child: IconButtonRound(
                icon: Icons.add,
                size: 52,
                variant: IconButtonVariant.filled,
                backgroundColor: context.colors.accent,
                iconColor: context.colors.onAccent,
                onPressed: () => _createSnippet(context),
              ),
            ),
        ],
      ),
    );
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
          LibraryHeader(
            title: 'Snippets',
            titleSize: _oneHand ? 64 : 32,
            shrinkProgress: _oneHand ? _scrollProgress : 0.0,
          ),
          _buildTabBar(),
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load snippets',
            subtitle: p.error!,
            primaryActionLabel: 'Try again',
            onPrimaryAction: () => ref.read(snippetsProvider.notifier).loadSnippets(),
          ),
        ],
      );
    }

    return _buildSnippetsTab(context, p);
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _TabButton(
            label: 'Snippets',
            selected: _tab == 0,
            onTap: () => setState(() => _tab = 0),
          ),
          const SizedBox(width: 12),
          _TabButton(
            label: 'Bookmarks',
            selected: _tab == 1,
            onTap: () {
              setState(() => _tab = 1);
              ref.read(bookmarksProvider.notifier).loadBookmarks();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSnippetsTab(BuildContext context, SnippetsState p) {
    final items = p.snippets;
    final hasFilter = p.filterTag != null ||
        p.filterCollectionId != null ||
        p.filterCollectionId == -1;

    if (items.isEmpty && !hasFilter && p.collections.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          const OneHandSpacer(),
          LibraryHeader(
            title: 'Snippets',
            titleSize: _oneHand ? 64 : 32,
            shrinkProgress: _oneHand ? _scrollProgress : 0.0,
          ),
          _buildTabBar(),
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.format_quote_outlined,
            title: 'No snippets yet',
            subtitle: 'Highlight text while reading, or tap + to create one.',
            primaryActionLabel: 'New snippet',
            primaryActionIcon: Icons.add,
            onPrimaryAction: () => _createSnippet(context),
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const OneHandSpacer(),
        _buildHeader(p),
        _buildTabBar(),
        if (!p.selectionMode)
          StaggeredEntrance(
            child: FeaturePanel(
              icon: Icons.format_quote_rounded,
              title: 'Captured thoughts',
              subtitle:
                  'Highlights, notes, and quotes with just enough structure to find them again.',
              stats: [
                PanelStat(value: '${p.snippets.length}', label: 'Saved'),
                PanelStat(value: '${p.allTags.length}', label: 'Tags'),
                PanelStat(value: hasFilter ? 'Filtered' : 'Uncollected', label: 'View'),
              ],
            ),
          ),
        if (!p.selectionMode) ...[
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
              icon: Icons.format_quote_outlined,
              title: 'No matching snippets',
              subtitle: 'Try a different tag or remove the filter.',
            ),
          )
        else ...[
          SectionLabel(
            title: _sectionTitle(p),
            meta: '${items.length}',
          ),
          ...items.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: StaggeredEntrance(
                index: entry.$1 + 1,
                child: SnippetCard(
                  snippet: entry.$2,
                  selected: p.selectionMode && p.selectedIds.contains(entry.$2.id),
                  selectionMode: p.selectionMode,
                  onTap: () {
                    if (p.selectionMode) {
                      ref.read(snippetsProvider.notifier).toggleSelection(entry.$2.id);
                    } else {
                      _editSnippet(context, entry.$2, p);
                    }
                  },
                  onLongPress: () {
                    if (!p.selectionMode) {
                      ref.read(snippetsProvider.notifier).toggleSelection(entry.$2.id);
                    }
                  },
                  onOpenSource: entry.$2.bookId != null
                      ? () => _openBookReader(
                          context,
                          entry.$2.bookId!,
                          chapterId: entry.$2.chapterId,
                          scrollOffset: entry.$2.scrollPosition)
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

  Widget _buildHeader(SnippetsState p) {
    final sn = ref.read(snippetsProvider.notifier);
    if (p.selectionMode) {
      return LibraryHeader(
        title: '${p.selectedIds.length} selected',
        titleSize: _oneHand ? 64 : 32,
        actions: [
          IconButtonRound(
            icon: Icons.select_all_rounded,
            size: 36,
            variant: IconButtonVariant.tonal,
            iconColor: context.colors.textSecondary,
            tooltip: 'Select All',
            onPressed: p.selectedIds.length == p.snippets.length && p.snippets.isNotEmpty
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
      titleSize: _oneHand ? 64 : 32,
      shrinkProgress: _oneHand ? _scrollProgress : 0.0,
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

  void _openBookReader(BuildContext context, int bookId,
      {int? chapterId, double? scrollOffset}) {
    context.pushNamed(
      Routes.reader,
      extra: (
        bookId: bookId,
        snippetChapterId: chapterId,
        snippetScrollOffset: scrollOffset,
      ),
    );
  }

  void _createSnippet(BuildContext context) {
    SnippetDetailSheet.show(
      context,
      creating: true,
      onSave: (s) async {
        try {
          await ref.read(snippetsProvider.notifier).createSnippet(
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
        StashToast.show(
          ctx,
          message: 'Snippets deleted',
          icon: Icons.check,
        );
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
                title: Text('New collection', style: TextStyle(color: c.primary)),
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
                              Text('Accent colour',
                                  style: TextStyle(color: dc.secondary, fontSize: 13)),
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
                              child: Text('Cancel', style: TextStyle(color: dc.secondary)),
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
                  if (confirmed == true && nameController.text.trim().isNotEmpty) {
                    final hex = keyToHex[selectedColor] ?? '#FFE8A8';
                    final id = await sn.createCollection(nameController.text.trim(), color: hex);
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
          titleSize: _oneHand ? 64 : 32,
          shrinkProgress: _oneHand ? _scrollProgress : 0.0,
        ),
        _buildTabBar(),
        if (bp.loading && bookmarks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          if (bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: EmptyState(
                icon: Icons.bookmark_border_outlined,
                title: 'No bookmarks yet',
                subtitle: 'Tap the bookmark icon while reading to save a page.',
              ),
            )
          else
            ...bookmarks.map((b) =>
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: BookmarkCard(
                    bookmark: b,
                    onTap: () => _openBookmark(context, b),
                    onDelete: () => _confirmDeleteBookmark(context, b.id),
                  ),
                )),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _openBookmark(BuildContext context, Bookmark bookmark) async {
    if (bookmark.bookId == null) return;
    final repos = ref.read(repositoriesProvider);
    final chapter = await repos.manga.getMangaChapter(bookmark.chapterId);
    if (chapter == null || !context.mounted) return;
    final book = await repos.books.getBook(bookmark.bookId!);
    if (book == null) return;
    context.pushNamed(
      Routes.mangaReader,
      extra: (
      mangaId: bookmark.bookId,
      sourceId: book.source,
      mangaUrl: book.sourceUrl ?? '',
      chapterUrl: chapter.url,
      chapterName: chapter.name,
      pageNumber: bookmark.pageNumber,
      ) as MangaReaderArgs,
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
              'Cancel', style: TextStyle(color: context.colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
              'Remove', style: TextStyle(color: Color(0xFFC44C4C))),
        ),
      ],
    );
    if (confirmed == true && context.mounted) {
      await ref.read(bookmarksProvider.notifier).deleteBookmark(id);
      if (context.mounted) {
        StashToast.show(
            context, message: 'Bookmark removed', icon: Icons.check);
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

  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = selected ? color.withValues(alpha: 0.18) : c.surfaceMuted;
    final fg = selected ? color : c.textSecondary;
    final border = selected ? Border.all(color: color.withValues(alpha: 0.6)) : null;
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: border,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accentMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.accent : c.textSecondary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
