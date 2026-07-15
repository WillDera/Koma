import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/services/database_service.dart';
import '../../core/services/ebook_service.dart';
import '../../core/services/web_scraper_service.dart';
import '../../core/services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/import_sheet.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_header.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/toast.dart';
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
  double _scrollProgress = 0;

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
    super.dispose();
  }

  bool get _oneHand => context.watch<ThemeProvider>().oneHandMode;

  @override
  Widget build(BuildContext context) {
    final leftHanded = context.watch<ThemeProvider>().handMode == HandMode.left;
    return Consumer<LibraryProvider>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            SafeArea(bottom: false, child: _body(context, provider)),
            if (!provider.loading &&
                !provider.selectionMode &&
                provider.books.isNotEmpty)
              Positioned(
                left: leftHanded ? 20 : null,
                right: leftHanded ? null : 20,
                bottom: 12,
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
          ],
        );
      },
    );
  }

  // ── Body dispatcher ─────────────────────────────────────────────────

  Widget _body(BuildContext context, LibraryProvider provider) {
    if (provider.loading && provider.books.isEmpty) return _loading(context);
    if (provider.error != null) return _error(context, provider);
    if (provider.books.isEmpty) return _empty(context);
    return provider.isGridView ? _grid(context, provider) : _list(context, provider);
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
                  borderRadius: BorderRadius.all(Radius.circular(14))),
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

  Widget _grid(BuildContext context, LibraryProvider provider) {
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () => provider.loadBooks(),
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // spacer + header scroll with the grid
          const SliverToBoxAdapter(child: OneHandSpacer()),
          SliverToBoxAdapter(child: _header(context, provider)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text('All books',
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2)),
                  const Spacer(),
                  Text('${provider.books.length}',
                      style: TextStyle(
                          color: context.colors.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 0.6,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => LibraryBookCard(
                  book: provider.books[i],
                  variant: LibraryCardVariant.grid,
                  selected: provider.selectedIds.contains(provider.books[i].id),
                  selectionMode: provider.selectionMode,
                  onTap: () => provider.selectionMode
                      ? provider.toggleSelection(provider.books[i].id)
                      : _openReader(context, provider.books[i].id),
                  onLongPress: () =>
                      provider.toggleSelection(provider.books[i].id),
                ),
                childCount: provider.books.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, LibraryProvider provider) {
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () => provider.loadBooks(),
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const OneHandSpacer(),
          _header(context, provider, _oneHand),
          const SizedBox(height: 8),
          for (final book in provider.books)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: LibraryBookCard(
                book: book,
                variant: LibraryCardVariant.list,
                selected: provider.selectedIds.contains(book.id),
                selectionMode: provider.selectionMode,
                onTap: () => provider.selectionMode
                    ? provider.toggleSelection(book.id)
                    : _openReader(context, book.id),
                onLongPress: () => provider.toggleSelection(book.id),
              ),
            ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _header(BuildContext context, LibraryProvider provider,
      [bool oneHand = false]) {
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
    String? subtitle;
    final count = provider.books.length;
    if (count > 0) {
      subtitle = '$count book${count == 1 ? '' : 's'}';
    }
    return LibraryHeader(
      title: 'Library',
      subtitle: subtitle,
      titleSize: _oneHand ? 64 : 32,
      shrinkProgress: _oneHand ? _scrollProgress : 0.0,
    );
  }

  // ── Dialogs / import ────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, LibraryProvider provider) async {
    final confirmed = await StashDialog.show<bool>(context,
        title: 'Remove books?',
        content:
            'Delete ${provider.selectedIds.length} book${provider.selectedIds.length == 1 ? '' : 's'} and all their chapters?',
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: context.colors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFC44C4C)))),
        ]);
    if (confirmed == true) await provider.deleteSelected();
  }

  void _showImportOptions(BuildContext context) {
    ImportSheet.show(context, options: [
      ImportOption(
          icon: Icons.file_present_outlined,
          title: 'Import file',
          subtitle: 'EPUB, TXT, or Markdown',
          onTap: () => _importFile(context)),
      ImportOption(
          icon: Icons.link,
          title: 'Add URL',
          subtitle: 'Save a web article for offline',
          onTap: () => _showAddUrlDialog(context)),
      ImportOption(
          icon: Icons.edit_note,
          title: 'New snippet',
          subtitle: 'Capture a thought or quote',
          onTap: () => _showAddNoteDialog(context)),
    ]);
  }

  // ── File / web import ───────────────────────────────────────────────

  Future<void> _importFile(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'epub', 'fb2', 'txt', 'mobi', 'azw', 'azw3', 'kf8', 'md', 'html'
          ],
          allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      if (!context.mounted) return;
      final filePath = result.files.single.path!;
      final ebookSvc = EbookService();
      final parsed = await ebookSvc.parse(filePath);
      if (parsed == null) throw Exception('Unsupported format');
      if (!context.mounted) return;
      final db = context.read<DatabaseService>();
      final existing =
          await db.findLocalBook(parsed.book.title, parsed.book.author);
      if (existing != null) {
        if (context.mounted) {
          StashToast.show(context,
              message: '"${parsed.book.title}" is already in your library',
              icon: Icons.info_outline);
          _openReader(context, existing.id);
        }
        return;
      }
      final provider = context.read<LibraryProvider>();
      final bookId = await provider.addBook(parsed.book);
      for (final ch in parsed.chapters) {
        await db.insertChapter(ch.copyWith(bookId: bookId));
      }
      if (context.mounted) {
        StashToast.show(context,
            message:
                '"${parsed.book.title}" added (${parsed.chapters.length} chapters)',
            icon: Icons.check);
      }
    } catch (e) {
      if (context.mounted) {
        StashToast.show(context, message: 'Import failed: $e', icon: Icons.error_outline);
      }
    }
  }

  void _showAddUrlDialog(BuildContext context) {
    UrlImportDialog.show(context, onSubmit: (url) => _fetchWebContent(context, url));
  }

  Future<void> _fetchWebContent(BuildContext context, String url) async {
    if (url.isEmpty) return;
    if (!context.mounted) return;
    try {
      StashToast.show(context,
          message: 'Fetching content…',
          icon: Icons.cloud_download_outlined,
          duration: const Duration(seconds: 3));
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
              id: 0, title: cached.title, source: 'web', sourceUrl: url, totalChapters: 1);
          final bookId = await provider.addBook(book);
          await db.insertChapter(cached.copyWith(bookId: bookId));
          if (context.mounted) {
            StashToast.show(context, message: 'Loaded from cache', icon: Icons.check);
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
          totalChapters: 1);
      final bookId = await provider.addBook(book);
      await db.insertChapter(Chapter(
          id: 0,
          bookId: bookId,
          title: result.title,
          content: result.contentHtml,
          index: 0));
      await cache.cacheContent(url, result.title, result.contentHtml);
      if (context.mounted) {
        StashToast.show(context,
            message: '"${result.title}" added', icon: Icons.check);
      }
    } catch (e) {
      if (context.mounted) {
        StashToast.show(context,
            message: 'Failed to fetch: $e', icon: Icons.error_outline);
      }
    }
  }

  void _showAddNoteDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    StashDialog.show<void>(context,
        title: 'New note',
        contentWidget: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
              controller: contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Content')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: context.colors.textSecondary))),
          PremiumButton(
              label: 'Save',
              size: PremiumButtonSize.sm,
              onPressed: () {
                final t = titleCtrl.text.trim();
                final c = contentCtrl.text.trim();
                if (t.isEmpty || c.isEmpty) return;
                Navigator.pop(context);
                _createNote(context, t, c);
              }),
        ]);
  }

  Future<void> _createNote(BuildContext context, String title, String content) async {
    if (title.isEmpty || content.isEmpty) return;
    if (!context.mounted) return;
    try {
      await context
          .read<SnippetsProvider>()
          .createSnippet(text: content, sourceTitle: title, tags: ['note']);
      if (context.mounted) {
        StashToast.show(context, message: 'Note created', icon: Icons.check);
      }
    } catch (e) {
      if (context.mounted) {
        StashToast.show(context, message: 'Failed: $e', icon: Icons.error_outline);
      }
    }
  }

  void _openReader(BuildContext context, int bookId) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId)));
  }
}
