import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../app.dart' show routeObserver;
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/models/library_category.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/ebook_media_store.dart';
import '../../core/services/ebook_service.dart';
import '../../core/services/metadata_enrichment_service.dart';
import '../../core/services/web_scraper_service.dart';
import '../../core/utils/benchmark_logger.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/catalog_card_layout.dart';
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
import '../../widgets/horizontal_tab_swipe.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/toast.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with RouteAware {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _bookSearchCtrl = TextEditingController();
  final TextEditingController _mangaSearchCtrl = TextEditingController();
  bool _importingFile = false;
  _LibrarySection _section = _LibrarySection.books;
  _LibrarySort _sort = _LibrarySort.alphabetical;
  final Map<_LibraryFilter, _FilterMode> _filters = {
    for (final filter in _LibraryFilter.values) filter: _FilterMode.none,
  };
  int? _selectedCategoryId;
  final Map<int, String?> _mangaThumbnails = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).loadBooks();
      _loadThumbnails();
    });
    // In-app notification when an auto poll discovers new chapters. Cleared
    // by checkForNewChapters' loadBooks rebuild; a system notification is
    // deferred to the infra task (workmanager + flutter_local_notifications).
    ref.listenManual(libraryUpdateResultProvider, (prev, next) {
      if (next == null || next.totalNew == 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        StashToast.show(
          context,
          message:
              '${next.totalNew} new chapter${next.totalNew == 1 ? '' : 's'} in ${next.updatedNames.length} manga',
          icon: Icons.auto_awesome,
          duration: const Duration(seconds: 3),
        );
      });
    });
  }

  Future<void> _loadThumbnails() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbDir.exists()) return;
      final provider = ref.read(libraryProvider);
      final paths = <int, String?>{};
      for (final manga in provider.mangas) {
        if (manga.imageUrl != null && manga.imageUrl!.isNotEmpty) {
          final hash = sha256.convert(utf8.encode(manga.imageUrl!)).toString();
          final path = '${thumbDir.path}/$hash.jpg';
          paths[manga.id] = File(path).existsSync() ? path : null;
        }
      }
      if (mounted) setState(() => _mangaThumbnails.addAll(paths));
    } catch (_) {
      // ignore thumbnail loading failures
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bookSearchCtrl.dispose();
    _mangaSearchCtrl.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // A pushed route (e.g. reader) was popped and we're visible again.
    // Reload data — this is the Mihon-equivalent of Room Flow
    // reacting to an onPause write.
    ref.read(libraryProvider.notifier).loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final leftHanded = ref.watch(themeProvider).handMode == HandMode.left;
    final navClearance = MediaQuery.paddingOf(context).bottom + 84;
    final provider = ref.watch(libraryProvider);
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
              child: _AethelgardFab(
                iconData: AppIcons.add,
                onPressed: () => _showImportOptions(context),
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
  }

  // ── Body dispatcher ─────────────────────────────────────────────────

  Widget _body(BuildContext context, LibraryState provider) {
    if (provider.loading && provider.books.isEmpty && provider.mangas.isEmpty) {
      return _loading(context, provider.gridColumns);
    }
    if (provider.error != null) return _error(context, provider);
    if (provider.books.isEmpty && provider.mangas.isEmpty) {
      return _empty(context);
    }
    return _combined(context, provider);
  }

  // ── States ──────────────────────────────────────────────────────────

  Widget _loading(BuildContext context, int gridColumns) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: OneHandSpacer()),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Skeleton(height: 18, width: 120),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridColumns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, _) => LayoutBuilder(
                builder: (context, constraints) {
                  // Cover + 8 gap + 12 title skeleton must fit the cell height.
                  final coverH = (constraints.maxHeight - 20).clamp(
                    48.0,
                    200.0,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(
                        height: coverH,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Skeleton(height: 12, width: 100),
                    ],
                  );
                },
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, LibraryState provider) {
    return Column(
      children: [
        _header(context, provider),
        Expanded(
          child: EmptyState(
            icon: AppIcons.alert,
            title: 'Something went wrong',
            subtitle: provider.error!,
            primaryActionLabel: 'Try again',
            primaryActionIcon: AppIcons.refresh,
            onPrimaryAction: () =>
                ref.read(libraryProvider.notifier).loadBooks(),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      children: [
        _header(context, ref.read(libraryProvider)),
        Expanded(
          child: EmptyState(
            icon: AppIcons.bookOpen,
            title: 'Your library is empty',
            subtitle:
                'Import an EPUB, paste a URL, or write a note to begin your reading collection.',
            primaryActionLabel: 'Add to library',
            primaryActionIcon: AppIcons.add,
            onPrimaryAction: () => _showImportOptions(context),
          ),
        ),
      ],
    );
  }

  // ── Normal content (scrolling includes spacer → header → grid/list) ──

  void _setSection(_LibrarySection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  Widget _combined(BuildContext context, LibraryState provider) {
    return HorizontalTabSwipe(
      tabIndex: _section == _LibrarySection.books ? 0 : 1,
      tabCount: 2,
      onTabChanged: (i) => _setSection(
        i == 0 ? _LibrarySection.books : _LibrarySection.manga,
      ),
      child: RefreshIndicator(
        color: context.colors.accent,
        backgroundColor: context.colors.surface,
        onRefresh: () => ref.read(libraryProvider.notifier).loadBooks(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: OneHandSpacer()),
            SliverToBoxAdapter(child: _header(context, provider)),
            SliverToBoxAdapter(
              child: _LibraryControls(
                section: _section,
                bookCount: provider.books.length,
                mangaCount: provider.mangas.length,
                onSectionChanged: _setSection,
              ),
            ),
            if (_section == _LibrarySection.books)
              _BookShelf(
                key: const ValueKey('books-shelf'),
                books: _visibleBooks(provider.books),
                provider: provider,
                notifier: ref.read(libraryProvider.notifier),
                showSourcePills: provider.showSourcePills,
                onOpen: (id) => openBookFromCollection(context, id),
                onBookLongPress: _showBookActions,
              )
            else ...[
              if (_mangaSearchCtrl.text.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.travel_explore,
                        color: context.colors.accent,
                      ),
                      title: Text(
                        'Search globally for “${_mangaSearchCtrl.text.trim()}”',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: context.colors.textTertiary,
                      ),
                      onTap: () => context.pushNamed(
                        Routes.globalSearch,
                        extra: _mangaSearchCtrl.text.trim(),
                      ),
                    ),
                  ),
                ),
              _MangaShelf(
                key: const ValueKey('manga-shelf'),
                mangas: _visibleMangas(provider.mangas),
                gridView: provider.isGridView,
                provider: provider,
                notifier: ref.read(libraryProvider.notifier),
                extensionNames: provider.extensionNames,
                mangaThumbnails: _mangaThumbnails,
                showSourcePills: provider.showSourcePills,
                onOpen: (manga) => _openManga(context, manga),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _header(BuildContext context, LibraryState provider) {
    final c = context.colors;
    if (provider.selectionMode) {
      return LibraryHeader(
        title: '${provider.selectedIds.length} selected',
        actions: [
          IconButtonRound(
            icon: Icons.select_all_rounded,
            size: 38,
            variant: IconButtonVariant.tonal,
            iconColor: c.textSecondary,
            onPressed: ref.read(libraryProvider.notifier).selectAll,
          ),
          const SizedBox(width: 8),
          IconButtonRound(
            icon: Icons.delete_outline,
            size: 38,
            variant: IconButtonVariant.tonal,
            iconColor: const Color(0xFFC44C4C),
            onPressed: () => _confirmDelete(context, provider),
          ),
          const SizedBox(width: 8),
          IconButtonRound(
            icon: Icons.close,
            size: 38,
            variant: IconButtonVariant.tonal,
            onPressed: ref.read(libraryProvider.notifier).clearSelection,
          ),
          const SizedBox(width: 8),
        ],
      );
    }
    return LibraryHeader(
      title: 'Library',
      subtitle: _section == _LibrarySection.books
          ? '${provider.books.length} books'
          : '${provider.mangas.length} manga',
      actions: [
        IconButtonRound(
          iconData: provider.isGridView ? AppIcons.list : AppIcons.grid,
          size: 38,
          variant: IconButtonVariant.tonal,
          tooltip: 'Toggle layout',
          onPressed: ref.read(libraryProvider.notifier).toggleLayout,
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButtonRound(
              icon: Icons.tune_rounded,
              size: 38,
              variant: IconButtonVariant.tonal,
              tooltip: 'Filter and sort library',
              onPressed: _showFilterSheet,
            ),
            if (_filters.values.any((mode) => mode != _FilterMode.none) ||
                _selectedCategoryId != null ||
                _bookSearchCtrl.text.trim().isNotEmpty ||
                _mangaSearchCtrl.text.trim().isNotEmpty)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        IconButtonRound(
          iconData: AppIcons.search,
          size: 38,
          variant: IconButtonVariant.tonal,
          tooltip: 'Search library',
          onPressed: () => context.pushNamed(Routes.search),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Filter / sort sheet ─────────────────────────────────────────────

  void _showFilterSheet() {
    final filters = Map<_LibraryFilter, _FilterMode>.from(_filters);
    var selectedSort = _sort;
    var showSourcePills = ref.read(libraryProvider).showSourcePills;
    var selectedCategoryId = _selectedCategoryId;
    final categories = ref.read(libraryProvider).categories;
    final queryCtrl = _section == _LibrarySection.books
        ? _bookSearchCtrl
        : _mangaSearchCtrl;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _LibraryFilterSheet(
          filters: filters,
          sort: selectedSort,
          showSourcePills: showSourcePills,
          queryController: queryCtrl,
          queryHint: _section == _LibrarySection.books
              ? 'Filter books'
              : 'Filter manga',
          categories: _section == _LibrarySection.manga ? categories : const [],
          selectedCategoryId: selectedCategoryId,
          onCategoryChanged: (id) {
            setSheetState(() => selectedCategoryId = id);
            setState(() => _selectedCategoryId = id);
          },
          onQueryChanged: (_) => setState(() {}),
          onFilterChanged: (filter) {
            final next = switch (filters[filter] ?? _FilterMode.none) {
              _FilterMode.none => _FilterMode.include,
              _FilterMode.include => _FilterMode.exclude,
              _FilterMode.exclude => _FilterMode.none,
            };
            setSheetState(() => filters[filter] = next);
            setState(() => _filters[filter] = next);
          },
          onSortChanged: (sort) {
            setSheetState(() => selectedSort = sort);
            setState(() => _sort = sort);
          },
          onShowSourcePillsChanged: (value) {
            setSheetState(() => showSourcePills = value);
            ref.read(libraryProvider.notifier).setShowSourcePills(value);
          },
        ),
      ),
    );
  }

  List<Book> _visibleBooks(List<Book> books) {
    final query = _bookSearchCtrl.text.trim().toLowerCase();
    final searched = query.isEmpty
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
    final filtered = searched
        .where(
          (book) => _filters.entries.every(
            (entry) =>
                _matchesFilter(entry.value, _bookMatches(book, entry.key)),
          ),
        )
        .toList();
    filtered.sort(
      (a, b) => switch (_sort) {
        _LibrarySort.alphabetical => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        _LibrarySort.author => (a.author ?? '').toLowerCase().compareTo(
          (b.author ?? '').toLowerCase(),
        ),
        _LibrarySort.progress => b.progress.compareTo(a.progress),
      },
    );
    return filtered;
  }

  List<Manga> _visibleMangas(List<Manga> mangas) {
    final query = _mangaSearchCtrl.text.trim().toLowerCase();
    final searched = query.isEmpty
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
    final inCategory = _selectedCategoryId == null
        ? searched
        : searched
            .where((m) => m.categoryIds.contains(_selectedCategoryId))
            .toList();
    final filtered = inCategory
        .where(
          (manga) => _filters.entries.every(
            (entry) =>
                _matchesFilter(entry.value, _mangaMatches(manga, entry.key)),
          ),
        )
        .toList();
    filtered.sort(
      (a, b) => switch (_sort) {
        _LibrarySort.alphabetical => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _LibrarySort.author =>
          (a.author ?? a.artist ?? '').toLowerCase().compareTo(
            (b.author ?? b.artist ?? '').toLowerCase(),
          ),
        _LibrarySort.progress => b.readingStatus.compareTo(a.readingStatus),
      },
    );
    return filtered;
  }

  bool _bookMatches(Book book, _LibraryFilter filter) => switch (filter) {
    _LibraryFilter.unread => book.progress <= 0,
    _LibraryFilter.newlyAdded => book.createdAt.isAfter(
      DateTime.now().subtract(const Duration(days: 7)),
    ),
  };

  bool _mangaMatches(Manga manga, _LibraryFilter filter) => switch (filter) {
    _LibraryFilter.unread => manga.readingStatus == 0,
    _LibraryFilter.newlyAdded => manga.createdAt.isAfter(
      DateTime.now().subtract(const Duration(days: 7)),
    ),
  };

  bool _matchesFilter(_FilterMode mode, bool applies) => switch (mode) {
    _FilterMode.none => true,
    _FilterMode.include => applies,
    _FilterMode.exclude => !applies,
  };

  // ── Dialogs / import ────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, LibraryState provider) async {
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Remove titles?',
      content:
          'Delete ${provider.selectedIds.length} title${provider.selectedIds.length == 1 ? '' : 's'}?',
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
    if (confirmed == true) {
      await ref.read(libraryProvider.notifier).deleteSelected();
    }
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
      final repos = ref.read(repositoriesProvider);
      final ln = ref.read(libraryProvider.notifier);
      final ebookSvc = EbookService();
      final parsed = await ebookSvc.parse(filePath);
      if (parsed == null) throw Exception('Unsupported format');
      if (!context.mounted) return;
      final existing = await repos.books.findLocalBook(
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
          openBookReader(context, bookId: existing.id);
        }
        return;
      }
      final bookId = await ln.addBook(parsed.book);
      final chapters = await EbookMediaStore.promote(
        sessionId: parsed.mediaSessionId,
        bookId: bookId,
        chapters: parsed.chapters,
      );
      for (final ch in chapters) {
        await repos.books.insertChapter(ch);
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
      final repos = ref.read(repositoriesProvider);
      final cache = CacheService(repos);
      final cached = await cache.getCached(url);
      if (cached != null) {
        if (context.mounted) {
          final provider = ref.read(libraryProvider.notifier);
          final book = Book(
            id: 0,
            title: cached.title,
            source: 'web',
            sourceUrl: url,
            totalChapters: 1,
          );
          final bookId = await provider.addBook(book);
          await repos.books.insertChapter(cached.copyWith(bookId: bookId));
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
      final provider = ref.read(libraryProvider.notifier);
      final book = Book(
        id: 0,
        title: result.title,
        author: result.author,
        source: 'web',
        sourceUrl: url,
        totalChapters: 1,
      );
      final bookId = await provider.addBook(book);
      await repos.books.insertChapter(
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

  Future<void> _fetchMetadata(Book book) async {
    final enrichment = ref.read(metadataEnrichmentProvider.notifier);
    await enrichment.enrichOne(book);
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).loadBooks();
    if (!mounted) return;
    final progress = ref.read(metadataEnrichmentProvider);
    StashToast.show(
      context,
      message: progress.lastMessage ?? 'Done',
      icon: progress.errors.isEmpty ? Icons.auto_awesome : Icons.error_outline,
    );
  }

  void _showBookActions(Book book) {
    final notifier = ref.read(libraryProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.colors;
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.auto_awesome, color: c.accent),
                  title: const Text('Fetch metadata'),
                  subtitle: Text(
                    'Author, cover, genres, release date',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _fetchMetadata(book);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: c.textPrimary,
                  ),
                  title: const Text('Select'),
                  onTap: () {
                    Navigator.pop(ctx);
                    notifier.toggleSelection('b:${book.id}');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
      await ref
          .read(snippetsProvider.notifier)
          .createSnippet(text: content, sourceTitle: title, tags: ['note']);
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

  void _openManga(BuildContext context, Manga manga) {
    context.pushNamed(
      Routes.mangaDetail,
      extra:
          (
                sourceId: manga.sourceId,
                url: manga.url,
                title: manga.name,
                manga: manga, // Pass full Manga object for instant first frame
                memo: manga.memo,
              )
              as MangaDetailArgs,
    );
  }
}

enum _LibrarySection { books, manga }

enum _LibrarySort { alphabetical, author, progress }

enum _LibraryFilter { unread, newlyAdded }

enum _FilterMode { none, include, exclude }

class _LibraryControls extends StatelessWidget {
  final _LibrarySection section;
  final int bookCount;
  final int mangaCount;
  final ValueChanged<_LibrarySection> onSectionChanged;

  const _LibraryControls({
    required this.section,
    required this.bookCount,
    required this.mangaCount,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Figma: full-width Books | Manga segment under the header (px-5).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SegmentedControl<_LibrarySection>(
        segments: {
          _LibrarySection.books: 'Books ($bookCount)',
          _LibrarySection.manga: 'Manga ($mangaCount)',
        },
        value: section,
        onChanged: onSectionChanged,
        height: 40,
      ),
    );
  }
}

class _LibraryFilterSheet extends StatelessWidget {
  final Map<_LibraryFilter, _FilterMode> filters;
  final _LibrarySort sort;
  final bool showSourcePills;
  final TextEditingController queryController;
  final String queryHint;
  final List<LibraryCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_LibraryFilter> onFilterChanged;
  final ValueChanged<_LibrarySort> onSortChanged;
  final ValueChanged<bool> onShowSourcePillsChanged;

  const _LibraryFilterSheet({
    required this.filters,
    required this.sort,
    required this.showSourcePills,
    required this.queryController,
    required this.queryHint,
    this.categories = const [],
    this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onShowSourcePillsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textTertiary,
                  borderRadius: AppSpacing.brPill,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Filter',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryController,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: queryHint,
                prefixIcon: const Icon(Icons.search, size: 19),
              ),
            ),
            const SizedBox(height: 8),
            _FilterOption(
              icon: Icons.markunread_outlined,
              label: 'Unread',
              mode: filters[_LibraryFilter.unread] ?? _FilterMode.none,
              onTap: () => onFilterChanged(_LibraryFilter.unread),
            ),
            _FilterOption(
              icon: Icons.fiber_new_rounded,
              label: 'Newly added',
              mode: filters[_LibraryFilter.newlyAdded] ?? _FilterMode.none,
              onTap: () => onFilterChanged(_LibraryFilter.newlyAdded),
            ),
            if (categories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: c.border, height: 1),
              ),
              Text(
                'Categories',
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: selectedCategoryId == null,
                    onSelected: (_) => onCategoryChanged(null),
                  ),
                  for (final cat in categories)
                    ChoiceChip(
                      label: Text(cat.name),
                      selected: selectedCategoryId == cat.id,
                      onSelected: (_) => onCategoryChanged(
                        selectedCategoryId == cat.id ? null : cat.id,
                      ),
                    ),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: c.border, height: 1),
            ),
            AnimatedPress(
              onTap: () => onShowSourcePillsChanged(!showSourcePills),
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Icon(
                      Icons.label_outline_rounded,
                      size: 21,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Show source pills',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _TriStateGlyph(
                      mode: showSourcePills
                          ? _FilterMode.include
                          : _FilterMode.none,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: c.border, height: 1),
            ),
            Text(
              'Sort',
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _SortOption(
              icon: Icons.sort_by_alpha_rounded,
              label: 'Alphabetical order',
              selected: sort == _LibrarySort.alphabetical,
              onTap: () => onSortChanged(_LibrarySort.alphabetical),
            ),
            _SortOption(
              icon: Icons.person_outline_rounded,
              label: 'Author',
              selected: sort == _LibrarySort.author,
              onTap: () => onSortChanged(_LibrarySort.author),
            ),
            _SortOption(
              icon: Icons.donut_large_rounded,
              label: 'Progress',
              selected: sort == _LibrarySort.progress,
              onTap: () => onSortChanged(_LibrarySort.progress),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final _FilterMode mode;
  final VoidCallback onTap;

  const _FilterOption({
    required this.icon,
    required this.label,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$label filter',
      value: switch (mode) {
        _FilterMode.none => 'not applied',
        _FilterMode.include => 'included',
        _FilterMode.exclude => 'excluded',
      },
      child: AnimatedPress(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              Icon(icon, size: 21, color: c.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _TriStateGlyph(mode: mode),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Icon(icon, size: 21, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.accent : c.border,
                  width: selected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriStateGlyph extends StatelessWidget {
  final _FilterMode mode;

  const _TriStateGlyph({required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, glyph) = switch (mode) {
      _FilterMode.none => (c.textTertiary, null),
      _FilterMode.include => (c.accent, Icons.check_rounded),
      _FilterMode.exclude => (const Color(0xFFC44C4C), Icons.close_rounded),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: mode == _FilterMode.none ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: glyph == null ? null : Icon(glyph, size: 17, color: c.onAccent),
    );
  }
}

class _BookShelf extends StatelessWidget {
  final List<Book> books;
  final LibraryState provider;
  final LibraryNotifier notifier;
  final ValueChanged<int> onOpen;
  final ValueChanged<Book> onBookLongPress;
  final bool showSourcePills;

  const _BookShelf({
    super.key,
    required this.books,
    required this.provider,
    required this.notifier,
    required this.onOpen,
    required this.onBookLongPress,
    this.showSourcePills = true,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 260,
          child: EmptyState(
            icon: AppIcons.search,
            title: 'No books found',
            subtitle: 'Try another title, author, genre, or format.',
          ),
        ),
      );
    }
    final sw = Stopwatch()..start();
    late final Widget result;
    if (provider.isGridView) {
      // List card-style in a grid context falls back to comfortable grid.
      final variant = CatalogCardLayout.gridVariant(provider.cardVariant);
      result = SliverPadding(
        padding: CatalogCardLayout.paddingFor(variant),
        sliver: SliverGrid(
          gridDelegate: CatalogCardLayout.gridDelegate(
            columns: provider.gridColumns,
            variant: variant,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => StaggeredEntrance(
              index: i + 1,
              child: LibraryBookCard(
                book: books[i],
                variant: variant,
                selected: provider.selectedIds.contains('b:${books[i].id}'),
                selectionMode: provider.selectionMode,
                showSourcePills: provider.showSourcePills,
                onTap: () => provider.selectionMode
                    ? notifier.toggleSelection('b:${books[i].id}')
                    : onOpen(books[i].id),
                onLongPress: () => provider.selectionMode
                    ? notifier.toggleSelection('b:${books[i].id}')
                    : onBookLongPress(books[i]),
              ),
            ),
            childCount: books.length,
          ),
        ),
      );
      BenchmarkLogger.log(
        'book_shelf_build',
        'variant=${variant.name} count=${books.length} elapsed=${sw.elapsedMicroseconds}us',
      );
      return result;
    }
    result = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, index) {
          if (index.isOdd) return const SizedBox(height: 8);
          final i = index ~/ 2;
          return StaggeredEntrance(
            index: i + 1,
            child: LibraryBookCard(
              book: books[i],
              variant: LibraryCardVariant.list,
              selected: provider.selectedIds.contains('b:${books[i].id}'),
              selectionMode: provider.selectionMode,
              showSourcePills: provider.showSourcePills,
              onTap: () => provider.selectionMode
                  ? notifier.toggleSelection('b:${books[i].id}')
                  : onOpen(books[i].id),
              onLongPress: () => provider.selectionMode
                  ? notifier.toggleSelection('b:${books[i].id}')
                  : onBookLongPress(books[i]),
            ),
          );
        }, childCount: books.length * 2 - 1),
      ),
    );
    BenchmarkLogger.log(
      'book_shelf_build',
      'variant=list count=${books.length} elapsed=${sw.elapsedMicroseconds}us',
    );
    return result;
  }
}

class _MangaShelf extends StatelessWidget {
  final List<Manga> mangas;
  final bool gridView;
  final LibraryState provider;
  final LibraryNotifier notifier;
  final ValueChanged<Manga> onOpen;
  final Map<int, String?> mangaThumbnails;
  final Map<String, String> extensionNames;
  final bool showSourcePills;

  const _MangaShelf({
    super.key,
    required this.mangas,
    required this.gridView,
    required this.provider,
    required this.notifier,
    required this.onOpen,
    this.mangaThumbnails = const {},
    this.extensionNames = const {},
    this.showSourcePills = true,
  });

  @override
  Widget build(BuildContext context) {
    if (mangas.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 260,
          child: EmptyState(
            icon: AppIcons.search,
            title: 'No manga found',
            subtitle: 'Try another title, author, source, or genre.',
          ),
        ),
      );
    }
    final sw = Stopwatch()..start();
    late final Widget result;
    if (gridView) {
      final variant = CatalogCardLayout.gridVariant(provider.cardVariant);
      result = SliverPadding(
        padding: CatalogCardLayout.paddingFor(variant),
        sliver: SliverGrid(
          gridDelegate: CatalogCardLayout.gridDelegate(
            columns: provider.gridColumns,
            variant: variant,
          ),
          delegate: SliverChildBuilderDelegate((ctx, i) {
            final manga = mangas[i];
            return StaggeredEntrance(
              index: i + 1,
              child: _MangaLibraryCard(
                manga: manga,
                newChapterCount: provider.newChapters[manga.id] ?? 0,
                localImagePath: mangaThumbnails[manga.id],
                selected: provider.selectedIds.contains('m:${manga.id}'),
                selectionMode: provider.selectionMode,
                extensionName: extensionNames[manga.sourceId] ?? manga.sourceId,
                showSourcePills: showSourcePills,
                variant: variant,
                onTap: () => provider.selectionMode
                    ? notifier.toggleSelection('m:${manga.id}')
                    : onOpen(manga),
                onLongPress: () => notifier.toggleSelection('m:${manga.id}'),
              ),
            );
          }, childCount: mangas.length),
        ),
      );
      BenchmarkLogger.log(
        'manga_shelf_build',
        'variant=grid count=${mangas.length} elapsed=${sw.elapsedMicroseconds}us',
      );
      return result;
    }
    result = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, index) {
          if (index.isOdd) return const SizedBox(height: 8);
          final i = index ~/ 2;
          final manga = mangas[i];
          return StaggeredEntrance(
            index: i + 1,
            child: _MangaLibraryRow(
              manga: manga,
              newChapterCount: provider.newChapters[manga.id] ?? 0,
              localImagePath: mangaThumbnails[manga.id],
              selected: provider.selectedIds.contains('m:${manga.id}'),
              selectionMode: provider.selectionMode,
              extensionName: extensionNames[manga.sourceId] ?? manga.sourceId,
              showSourcePills: showSourcePills,
              onTap: () => provider.selectionMode
                  ? notifier.toggleSelection('m:${manga.id}')
                  : onOpen(manga),
              onLongPress: () => notifier.toggleSelection('m:${manga.id}'),
            ),
          );
        }, childCount: mangas.length * 2 - 1),
      ),
    );
    BenchmarkLogger.log(
      'manga_shelf_build',
      'variant=list count=${mangas.length} elapsed=${sw.elapsedMicroseconds}us',
    );
    return result;
  }
}

// ── Manga library cards ────────────────────────────────────────────────

class _MangaLibraryCard extends ConsumerWidget {
  final Manga manga;
  final VoidCallback onTap;
  final String? localImagePath;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onLongPress;
  final String? extensionName;
  final bool showSourcePills;
  final LibraryCardVariant variant;
  final int newChapterCount;

  const _MangaLibraryCard({
    required this.manga,
    required this.onTap,
    this.localImagePath,
    this.selected = false,
    this.selectionMode = false,
    this.onLongPress,
    this.extensionName,
    this.showSourcePills = true,
    this.variant = LibraryCardVariant.grid,
    this.newChapterCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final headers = ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
    if (variant == LibraryCardVariant.overlay) {
      return AnimatedPress(
        onTap: onTap,
        onLongPress: onLongPress,
        scaleDown: 0.99,
        child: ClipRRect(
          borderRadius: AppSpacing.brMd,
          child: AspectRatio(
            aspectRatio: 0.65,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: localImagePath != null
                      ? Image.file(
                          File(localImagePath!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(c),
                        )
                      : manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                      ? Image(
                          image: cachedCover(manga.imageUrl!, headers: headers),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(c),
                        )
                      : _placeholder(c),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 1.0],
                      ),
                    ),
                  ),
                ),
                if (showSourcePills)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: AppSpacing.brPill,
                      ),
                      child: Text(
                        extensionName ?? manga.sourceId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (newChapterCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _NewChapterBadge(count: newChapterCount),
                  ),
                if (selectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? c.accent
                            : Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: selected
                          ? Icon(Icons.check, size: 14, color: c.onAccent)
                          : null,
                    ),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    manga.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      shadows: const [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black54,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AnimatedPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppSpacing.brMd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  localImagePath != null
                      ? Image.file(
                          File(localImagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(c),
                        )
                      : manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                      ? Image(
                          image: cachedCover(
                            manga.imageUrl!,
                            headers: headers,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(c),
                        )
                      : _placeholder(c),
                  if (showSourcePills)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: AppSpacing.brPill,
                        ),
                        child: Text(
                          extensionName ?? manga.sourceId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (newChapterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _NewChapterBadge(count: newChapterCount),
                    ),
                  if (selectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected
                              ? c.accent
                              : Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: selected
                            ? Icon(Icons.check, size: 14, color: c.onAccent)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            manga.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (!showSourcePills &&
              extensionName != null &&
              extensionName!.isNotEmpty)
            Text(
              extensionName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            )
          else if (manga.author != null && manga.author!.isNotEmpty)
            Text(
              manga.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(KomaColors c) => ColoredBox(
    color: c.iconWell,
    child: Center(
      child: Icon(Icons.image_outlined, size: 28, color: c.textTertiary),
    ),
  );
}

class _MangaLibraryRow extends ConsumerWidget {
  final Manga manga;
  final VoidCallback onTap;
  final String? localImagePath;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onLongPress;
  final String? extensionName;
  final bool showSourcePills;
  final int newChapterCount;

  const _MangaLibraryRow({
    required this.manga,
    required this.onTap,
    this.localImagePath,
    this.selected = false,
    this.selectionMode = false,
    this.onLongPress,
    this.extensionName,
    this.showSourcePills = true,
    this.newChapterCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final headers = ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
    return Padding(
      padding: EdgeInsets.zero,
      child: AnimatedPress(
        onTap: onTap,
        onLongPress: onLongPress,
        scaleDown: 0.99,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? c.accentMuted : c.surface,
            borderRadius: AppSpacing.brMd,
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? c.accent : c.textTertiary,
                ),
                const SizedBox(width: 12),
              ],
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppSpacing.brMd,
                    child: localImagePath != null
                        ? Image.file(
                            File(localImagePath!),
                            width: 52,
                            height: 74,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(c, 52, 74),
                          )
                        : manga.imageUrl != null && manga.imageUrl!.isNotEmpty
                        ? Image(
                            image: cachedCover(
                              manga.imageUrl!,
                              headers: headers,
                              width: 52,
                              height: 74,
                            ),
                            width: 52,
                            height: 74,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(c, 52, 74),
                          )
                        : _placeholder(c, 52, 74),
                  ),
                  if (showSourcePills)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: AppSpacing.brPill,
                        ),
                        child: Text(
                          extensionName ?? manga.sourceId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (newChapterCount > 0)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: _NewChapterBadge(
                        count: newChapterCount,
                        small: true,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!showSourcePills) ...[
                      const SizedBox(height: 2),
                      Text(
                        extensionName ?? manga.sourceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (manga.author != null && manga.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        manga.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (newChapterCount > 0)
                _NewChapterBadge(count: newChapterCount)
              else
                Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(KomaColors c, double w, double h) => Container(
    width: w,
    height: h,
    color: c.surfaceMuted,
    child: Center(
      child: Icon(Icons.image_outlined, size: 24, color: c.textTertiary),
    ),
  );
}

/// Accent "N" pill shown on library manga cards when a poll has discovered
/// chapters that haven't been opened yet.
class _NewChapterBadge extends StatelessWidget {
  final int count;
  final bool small;

  const _NewChapterBadge({required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: c.onAccent,
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Aethelgard-style FAB — circular, primary-colored, with the signature
/// soft outer glow (`0 0 20px rgba(accent, 0.3)`). Uses Hugeicons.
class _AethelgardFab extends StatelessWidget {
  final AppIconData iconData;
  final VoidCallback? onPressed;

  const _AethelgardFab({required this.iconData, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onPressed,
      scaleDown: 0.90,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          boxShadow: AppSpacing.fabGlow(accent: c.accent),
        ),
        child: Center(
          child: AppIcon(data: iconData, size: 26, color: c.onAccent),
        ),
      ),
    );
  }
}
