import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/models/manga.dart';
import '../../core/services/database_service.dart';
import '../../core/services/ebook_service.dart';
import '../../core/services/web_scraper_service.dart';
import '../../core/services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';

import '../../widgets/animated_press.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/import_sheet.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_header.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/toast.dart';
import '../extensions/manga_detail_screen.dart';
import '../reader/reader_screen.dart';
import '../snippets/snippets_provider.dart';
import 'library_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _bookSearchCtrl = TextEditingController();
  final TextEditingController _mangaSearchCtrl = TextEditingController();
  double _scrollProgress = 0;
  bool _importingFile = false;
  _LibrarySection _section = _LibrarySection.books;
  _LibrarySort _sort = _LibrarySort.recent;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadBooks();
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
    _bookSearchCtrl.dispose();
    _mangaSearchCtrl.dispose();
    super.dispose();
  }

  bool get _oneHand => context.watch<ThemeProvider>().oneHandMode;

  @override
  Widget build(BuildContext context) {
    final leftHanded = context.watch<ThemeProvider>().handMode == HandMode.left;
    final navClearance = MediaQuery.paddingOf(context).bottom + 84;
    return Consumer<LibraryProvider>(
      builder: (context, provider, _) {
        return ScreenBackdrop(
          child: Stack(
            children: [
              SafeArea(bottom: false, child: _body(context, provider)),
              if (!provider.loading &&
                  !provider.selectionMode &&
                  (provider.books.isNotEmpty || provider.mangas.isNotEmpty))
                Positioned(
                  left: leftHanded ? 20 : null,
                  right: leftHanded ? null : 20,
                  bottom: navClearance,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButtonRound(
                        icon: provider.isGridView
                            ? Icons.list
                            : Icons.grid_view_rounded,
                        size: 44,
                        variant: IconButtonVariant.filled,
                        backgroundColor: context.colors.surfaceMuted,
                        iconColor: context.colors.textPrimary,
                        onPressed: provider.toggleLayout,
                      ),
                      const SizedBox(height: 10),
                      IconButtonRound(
                        icon: Icons.add,
                        size: 52,
                        variant: IconButtonVariant.filled,
                        backgroundColor: context.colors.accent,
                        iconColor: context.colors.onAccent,
                        onPressed: () => _showImportOptions(context),
                      ),
                    ],
                  ),
                ),
              if (_importingFile)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: context.colors.accent,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Preparing MOBI...',
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Body dispatcher ─────────────────────────────────────────────────

  Widget _body(BuildContext context, LibraryProvider provider) {
    if (provider.loading && provider.books.isEmpty && provider.mangas.isEmpty)
      return _loading(context);
    if (provider.error != null) return _error(context, provider);
    if (provider.books.isEmpty && provider.mangas.isEmpty)
      return _empty(context);
    return _combined(context, provider);
  }

  // ── States ──────────────────────────────────────────────────────────

  Widget _loading(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        const OneHandSpacer(),
        const Skeleton(height: 18, width: 120),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.62,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(
                height: 200,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              SizedBox(height: 8),
              Skeleton(height: 12, width: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, LibraryProvider provider) {
    return Column(
      children: [
        _header(context, provider),
        Expanded(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            subtitle: provider.error!,
            primaryActionLabel: 'Try again',
            primaryActionIcon: Icons.refresh,
            onPrimaryAction: () => provider.loadBooks(),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      children: [
        _header(context, context.read<LibraryProvider>()),
        Expanded(
          child: EmptyState(
            icon: Icons.auto_stories_outlined,
            title: 'Your library is empty',
            subtitle:
                'Import an EPUB, paste a URL, or write a note to begin your reading collection.',
            primaryActionLabel: 'Add to library',
            primaryActionIcon: Icons.add,
            onPrimaryAction: () => _showImportOptions(context),
          ),
        ),
      ],
    );
  }

  // ── Normal content (scrolling includes spacer → header → grid/list) ──

  Widget _combined(BuildContext context, LibraryProvider provider) {
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () => provider.loadBooks(),
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const OneHandSpacer(),
          _header(context, provider, _oneHand),
          if (!provider.selectionMode)
            StaggeredEntrance(
              index: 0,
              child: FeaturePanel(
                icon: Icons.auto_stories_outlined,
                title: 'Your reading stack',
                subtitle:
                    'Books, manga, web saves, and notes arranged for fast return.',
                stats: [
                  PanelStat(value: '${provider.books.length}', label: 'Books'),
                  PanelStat(value: '${provider.mangas.length}', label: 'Manga'),
                  PanelStat(
                    value:
                        '${provider.books.where((b) => b.progress > 0).length}',
                    label: 'Active',
                  ),
                ],
              ),
            ),
          _LibraryControls(
            section: _section,
            sort: _sort,
            bookCount: provider.books.length,
            mangaCount: provider.mangas.length,
            queryController: _section == _LibrarySection.books
                ? _bookSearchCtrl
                : _mangaSearchCtrl,
            onSectionChanged: (section) => setState(() => _section = section),
            onSortChanged: (sort) => setState(() => _sort = sort),
            onQueryChanged: (_) => setState(() {}),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _section == _LibrarySection.books
                ? _BookShelf(
                    key: const ValueKey('books-shelf'),
                    books: _visibleBooks(provider.books),
                    provider: provider,
                    onOpen: (id) => _openReader(context, id),
                  )
                : _MangaShelf(
                    key: const ValueKey('manga-shelf'),
                    mangas: _visibleMangas(provider.mangas),
                    gridView: provider.isGridView,
                    onOpen: (manga) => _openManga(context, manga),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _header(
    BuildContext context,
    LibraryProvider provider, [
    bool oneHand = false,
  ]) {
    if (provider.selectionMode) {
      return LibraryHeader(
        title: '${provider.selectedIds.length} selected',
        actions: [
          IconButtonRound(
            icon: Icons.delete_outline,
            size: 40,
            variant: IconButtonVariant.tonal,
            iconColor: const Color(0xFFC44C4C),
            onPressed: () => _confirmDelete(context, provider),
          ),
          const SizedBox(width: 8),
          IconButtonRound(
            icon: Icons.close,
            size: 40,
            variant: IconButtonVariant.tonal,
            onPressed: provider.clearSelection,
          ),
          const SizedBox(width: 8),
        ],
      );
    }
    return LibraryHeader(
      title: 'Library',
      titleSize: _oneHand ? 64 : 32,
      shrinkProgress: _oneHand ? _scrollProgress : 0.0,
    );
  }

  List<Book> _visibleBooks(List<Book> books) {
    final query = _bookSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? books.toList()
        : books.where((book) {
            final haystack = [
              book.title,
              book.author ?? '',
              book.genre,
              book.fileExtension,
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
    filtered.sort(
      (a, b) => switch (_sort) {
        _LibrarySort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        _LibrarySort.author => (a.author ?? '').toLowerCase().compareTo(
          (b.author ?? '').toLowerCase(),
        ),
        _LibrarySort.progress => b.progress.compareTo(a.progress),
        _LibrarySort.recent => b.updatedAt.compareTo(a.updatedAt),
      },
    );
    return filtered;
  }

  List<Manga> _visibleMangas(List<Manga> mangas) {
    final query = _mangaSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? mangas.toList()
        : mangas.where((manga) {
            final haystack = [
              manga.name,
              manga.author ?? '',
              manga.artist ?? '',
              manga.sourceId,
              ...manga.genres,
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
    filtered.sort(
      (a, b) => switch (_sort) {
        _LibrarySort.title => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _LibrarySort.author =>
          (a.author ?? a.artist ?? '').toLowerCase().compareTo(
            (b.author ?? b.artist ?? '').toLowerCase(),
          ),
        _LibrarySort.progress => b.readingStatus.compareTo(a.readingStatus),
        _LibrarySort.recent => b.updatedAt.compareTo(a.updatedAt),
      },
    );
    return filtered;
  }

  // ── Dialogs / import ────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, LibraryProvider provider) async {
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Remove books?',
      content:
          'Delete ${provider.selectedIds.length} book${provider.selectedIds.length == 1 ? '' : 's'} and all their chapters?',
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
            'Delete',
            style: TextStyle(color: Color(0xFFC44C4C)),
          ),
        ),
      ],
    );
    if (confirmed == true) await provider.deleteSelected();
  }

  void _showImportOptions(BuildContext context) {
    ImportSheet.show(
      context,
      options: [
        ImportOption(
          icon: Icons.file_present_outlined,
          title: 'Import file',
          subtitle: 'EPUB, TXT, or Markdown',
          onTap: () => _importFile(context),
        ),
        ImportOption(
          icon: Icons.link,
          title: 'Add URL',
          subtitle: 'Save a web article for offline',
          onTap: () => _showAddUrlDialog(context),
        ),
        ImportOption(
          icon: Icons.edit_note,
          title: 'New snippet',
          subtitle: 'Capture a thought or quote',
          onTap: () => _showAddNoteDialog(context),
        ),
      ],
    );
  }

  // ── File / web import ───────────────────────────────────────────────

  bool _isMobiFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return const {'mobi', 'azw', 'azw3', 'kf8'}.contains(ext);
  }

  Future<void> _importFile(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'epub',
          'fb2',
          'txt',
          'mobi',
          'azw',
          'azw3',
          'kf8',
          'md',
          'html',
        ],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      if (!context.mounted) return;
      final filePath = result.files.single.path!;
      final showMobiLoader = _isMobiFile(filePath);
      if (showMobiLoader && mounted) {
        setState(() => _importingFile = true);
      }
      final db = context.read<DatabaseService>();
      final provider = context.read<LibraryProvider>();
      final ebookSvc = EbookService();
      final parsed = await ebookSvc.parse(filePath);
      if (parsed == null) throw Exception('Unsupported format');
      if (!context.mounted) return;
      final existing = await db.findLocalBook(
        parsed.book.title,
        parsed.book.author,
      );
      if (existing != null) {
        if (context.mounted) {
          StashToast.show(
            context,
            message: '"${parsed.book.title}" is already in your library',
            icon: Icons.info_outline,
          );
          _openReader(context, existing.id);
        }
        return;
      }
      final bookId = await provider.addBook(parsed.book);
      for (final ch in parsed.chapters) {
        await db.insertChapter(ch.copyWith(bookId: bookId));
      }
      if (context.mounted) {
        StashToast.show(
          context,
          message:
              '"${parsed.book.title}" added (${parsed.chapters.length} chapters)',
          icon: Icons.check,
        );
      }
    } catch (e) {
      if (context.mounted) {
        StashToast.show(
          context,
          message: 'Import failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted && _importingFile) {
        setState(() => _importingFile = false);
      }
    }
  }

  void _showAddUrlDialog(BuildContext context) {
    UrlImportDialog.show(
      context,
      onSubmit: (url) => _fetchWebContent(context, url),
    );
  }

  Future<void> _fetchWebContent(BuildContext context, String url) async {
    if (url.isEmpty) return;
    if (!context.mounted) return;
    try {
      StashToast.show(
        context,
        message: 'Fetching content…',
        icon: Icons.cloud_download_outlined,
        duration: const Duration(seconds: 3),
      );
      final scraper = WebScraperService();
      final result = await scraper.fetchContent(url);
      if (!context.mounted) return;
      final db = context.read<DatabaseService>();
      final cache = CacheService(db.db);
      final cached = await cache.getCached(url);
      if (cached != null) {
        if (context.mounted) {
          final provider = context.read<LibraryProvider>();
          final book = Book(
            id: 0,
            title: cached.title,
            source: 'web',
            sourceUrl: url,
            totalChapters: 1,
          );
          final bookId = await provider.addBook(book);
          await db.insertChapter(cached.copyWith(bookId: bookId));
          if (context.mounted) {
            StashToast.show(
              context,
              message: 'Loaded from cache',
              icon: Icons.check,
            );
          }
        }
        return;
      }
      final provider = context.read<LibraryProvider>();
      final book = Book(
        id: 0,
        title: result.title,
        author: result.author,
        source: 'web',
        sourceUrl: url,
        totalChapters: 1,
      );
      final bookId = await provider.addBook(book);
      await db.insertChapter(
        Chapter(
          id: 0,
          bookId: bookId,
          title: result.title,
          content: result.contentHtml,
          index: 0,
        ),
      );
      await cache.cacheContent(url, result.title, result.contentHtml);
      if (context.mounted) {
        StashToast.show(
          context,
          message: '"${result.title}" added',
          icon: Icons.check,
        );
      }
    } catch (e) {
      if (context.mounted) {
        StashToast.show(
          context,
          message: 'Failed to fetch: $e',
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _showAddNoteDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    StashDialog.show<void>(
      context,
      title: 'New note',
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentCtrl,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Content'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        PremiumButton(
          label: 'Save',
          size: PremiumButtonSize.sm,
          onPressed: () {
            final t = titleCtrl.text.trim();
            final c = contentCtrl.text.trim();
            if (t.isEmpty || c.isEmpty) return;
            Navigator.pop(context);
            _createNote(context, t, c);
          },
        ),
      ],
    );
  }

  Future<void> _createNote(
    BuildContext context,
    String title,
    String content,
  ) async {
    if (title.isEmpty || content.isEmpty) return;
    if (!context.mounted) return;
    try {
      await context.read<SnippetsProvider>().createSnippet(
        text: content,
        sourceTitle: title,
        tags: ['note'],
      );
      if (context.mounted) {
        StashToast.show(context, message: 'Note created', icon: Icons.check);
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
  }

  void _openReader(BuildContext context, int bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId)),
    );
  }

  void _openManga(BuildContext context, Manga manga) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MangaDetailScreen(
          sourceId: manga.sourceId,
          url: manga.url,
          title: manga.name,
        ),
      ),
    );
  }
}

enum _LibrarySection { books, manga }

enum _LibrarySort { recent, title, author, progress }

class _LibraryControls extends StatefulWidget {
  final _LibrarySection section;
  final _LibrarySort sort;
  final int bookCount;
  final int mangaCount;
  final TextEditingController queryController;
  final ValueChanged<_LibrarySection> onSectionChanged;
  final ValueChanged<_LibrarySort> onSortChanged;
  final ValueChanged<String> onQueryChanged;

  const _LibraryControls({
    required this.section,
    required this.sort,
    required this.bookCount,
    required this.mangaCount,
    required this.queryController,
    required this.onSectionChanged,
    required this.onSortChanged,
    required this.onQueryChanged,
  });

  @override
  State<_LibraryControls> createState() => _LibraryControlsState();
}

class _LibraryControlsState extends State<_LibraryControls> {
  final FocusNode _searchFocus = FocusNode();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    widget.queryController.clear();
    widget.onQueryChanged('');
    setState(() => _searchOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          SegmentedControl<_LibrarySection>(
            segments: {
              _LibrarySection.books: 'Books ${widget.bookCount}',
              _LibrarySection.manga: 'Manga ${widget.mangaCount}',
            },
            value: widget.section,
            onChanged: widget.onSectionChanged,
            height: 42,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _searchOpen
                      ? TextField(
                          key: const ValueKey('library-search-field'),
                          controller: widget.queryController,
                          focusNode: _searchFocus,
                          onChanged: widget.onQueryChanged,
                          decoration: InputDecoration(
                            hintText: widget.section == _LibrarySection.books
                                ? 'Search books'
                                : 'Search manga',
                            prefixIcon: const Icon(Icons.search, size: 19),
                            suffixIcon: IconButton(
                              tooltip: 'Close search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _closeSearch,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('library-search-empty'),
                        ),
                ),
              ),
              if (!_searchOpen) ...[
                IconButtonRound(
                  icon: Icons.search_rounded,
                  tooltip: 'Search library',
                  onPressed: _openSearch,
                ),
                const SizedBox(width: 10),
              ],
              PopupMenuButton<_LibrarySort>(
                initialValue: widget.sort,
                tooltip: 'Sort library',
                color: c.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.brLg,
                  side: BorderSide(color: c.border, width: 0.5),
                ),
                onSelected: widget.onSortChanged,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _LibrarySort.recent,
                    child: Text('Recently updated'),
                  ),
                  PopupMenuItem(
                    value: _LibrarySort.title,
                    child: Text('Title'),
                  ),
                  PopupMenuItem(
                    value: _LibrarySort.author,
                    child: Text('Author'),
                  ),
                  PopupMenuItem(
                    value: _LibrarySort.progress,
                    child: Text('Progress'),
                  ),
                ],
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookShelf extends StatelessWidget {
  final List<Book> books;
  final LibraryProvider provider;
  final ValueChanged<int> onOpen;

  const _BookShelf({
    super.key,
    required this.books,
    required this.provider,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const SizedBox(
        height: 260,
        child: EmptyState(
          icon: Icons.search_off,
          title: 'No books found',
          subtitle: 'Try another title, author, genre, or format.',
        ),
      );
    }
    if (provider.isGridView) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 0.6,
          ),
          itemCount: books.length,
          itemBuilder: (ctx, i) => StaggeredEntrance(
            index: i + 1,
            child: LibraryBookCard(
              book: books[i],
              variant: LibraryCardVariant.grid,
              selected: provider.selectedIds.contains(books[i].id),
              selectionMode: provider.selectionMode,
              onTap: () => provider.selectionMode
                  ? provider.toggleSelection(books[i].id)
                  : onOpen(books[i].id),
              onLongPress: () => provider.toggleSelection(books[i].id),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final entry in books.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: StaggeredEntrance(
              index: entry.$1 + 1,
              child: LibraryBookCard(
                book: entry.$2,
                variant: LibraryCardVariant.list,
                selected: provider.selectedIds.contains(entry.$2.id),
                selectionMode: provider.selectionMode,
                onTap: () => provider.selectionMode
                    ? provider.toggleSelection(entry.$2.id)
                    : onOpen(entry.$2.id),
                onLongPress: () => provider.toggleSelection(entry.$2.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _MangaShelf extends StatelessWidget {
  final List<Manga> mangas;
  final bool gridView;
  final ValueChanged<Manga> onOpen;

  const _MangaShelf({
    super.key,
    required this.mangas,
    required this.gridView,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (mangas.isEmpty) {
      return const SizedBox(
        height: 260,
        child: EmptyState(
          icon: Icons.search_off,
          title: 'No manga found',
          subtitle: 'Try another title, author, source, or genre.',
        ),
      );
    }
    if (gridView) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.65,
          ),
          itemCount: mangas.length,
          itemBuilder: (ctx, i) {
            final manga = mangas[i];
            return StaggeredEntrance(
              index: i + 1,
              child: _MangaLibraryCard(
                manga: manga,
                onTap: () => onOpen(manga),
              ),
            );
          },
        ),
      );
    }
    return Column(
      children: [
        for (final entry in mangas.indexed)
          StaggeredEntrance(
            index: entry.$1 + 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _MangaLibraryRow(
                manga: entry.$2,
                onTap: () => onOpen(entry.$2),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Manga library cards ────────────────────────────────────────────────

class _MangaLibraryCard extends StatelessWidget {
  final Manga manga;
  final VoidCallback onTap;

  const _MangaLibraryCard({required this.manga, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brMd,
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                  ? Image.network(
                      manga.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(c),
                    )
                  : _placeholder(c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Text(
                manga.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(StashReaderColors c) => Container(
    color: c.surfaceMuted,
    child: Center(
      child: Icon(Icons.image_outlined, size: 28, color: c.textTertiary),
    ),
  );
}

class _MangaLibraryRow extends StatelessWidget {
  final Manga manga;
  final VoidCallback onTap;

  const _MangaLibraryRow({required this.manga, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedPress(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brMd,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppSpacing.brXs,
                child: manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                    ? Image.network(
                        manga.imageUrl!,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(c, 48, 64),
                      )
                    : _placeholder(c, 48, 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (manga.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        manga.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(StashReaderColors c, double w, double h) => Container(
    width: w,
    height: h,
    color: c.surfaceMuted,
    child: Center(
      child: Icon(Icons.image_outlined, size: 24, color: c.textTertiary),
    ),
  );
}
