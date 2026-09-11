import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/app_storage.dart';

import '../../app.dart' show routeObserver;
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/models/library_category.dart';
import '../../core/models/library_group.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/ebook_media_store.dart';
import '../../core/services/ebook_service.dart';
import '../../core/services/hidden_titles_prefs.dart';
import '../../core/services/koma_package_store.dart';
import '../../core/services/local_cbz_prefs.dart';
import '../../core/services/local_cbz_scanner.dart';
import '../../core/services/merge_manga_use_case.dart';
import '../../core/services/metadata_enrichment_service.dart';
import '../../core/services/android_storage_access.dart';
import '../../core/services/user_profile.dart';
import '../../widgets/toast.dart';
import '../../core/services/web_scraper_service.dart';
import '../../core/utils/benchmark_logger.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../features/reader/reader_settings_sheet.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/import_sheet.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_group_stack_card.dart';
import '../../widgets/library_header.dart';
import '../../widgets/library_layout_sheet.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/media_rail.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../core/repositories/manga_repository.dart' show InProgressManga;
import 'ebook_export_flow.dart';
import 'hidden_library_screen.dart';
import 'library_group_modal.dart';
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
  /// `null` = home rails; otherwise full grid for that section.
  _LibrarySection? _viewAllSection;
  _LibrarySort _sort = _LibrarySort.alphabetical;
  final Map<_LibraryFilter, _FilterMode> _filters = {
    for (final filter in _LibraryFilter.values) filter: _FilterMode.none,
  };
  int? _selectedCategoryId;
  final Map<int, String?> _mangaThumbnails = {};
  List<_ContinueItem> _continueItems = const [];

  _LibrarySection get _section =>
      _viewAllSection ?? _LibrarySection.books;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).loadBooks();
      _loadThumbnails();
      _loadContinue();
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
    ref.listenManual(historyRevisionProvider, (prev, next) {
      _loadContinue();
    });
  }

  Future<void> _loadContinue() async {
    try {
      final repos = ref.read(repositoriesProvider);
      final results = await Future.wait([
        repos.books.getInProgressBooks(),
        repos.manga.getInProgressManga(),
        HiddenTitlesPrefs.hiddenBookIds(),
      ]);
      if (!mounted) return;
      final hiddenBooks = results[2] as Set<int>;
      final books = [
        for (final b in results[0] as List<Book>)
          if (!hiddenBooks.contains(b.id)) b,
      ];
      // Drop manga that were removed from the library (row may still exist
      // with chapter history until the user clears history / deletes).
      // Also drop secret-shelf (hidden) titles.
      final mangas = (results[1] as List<InProgressManga>)
          .where(
            (m) =>
                m.manga.inLibrary &&
                !ViewerFlags.isHidden(m.manga.viewerFlags),
          )
          .toList(growable: false);
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final merged = <_ContinueItem>[
        for (final b in books)
          _ContinueItem.book(b, b.updatedAt),
        for (final m in mangas)
          _ContinueItem.manga(m, m.lastReadAt ?? epoch),
      ]..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      setState(() => _continueItems = merged);
    } catch (_) {
      // Continue rail is best-effort.
    }
  }

  Future<void> _loadThumbnails() async {
    try {
      final appDir = await AppStorage.documents();
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
    ref.read(libraryProvider.notifier).loadBooks();
    _loadContinue();
  }

  @override
  Widget build(BuildContext context) {
    final leftHanded = ref.watch(themeProvider).handMode == HandMode.left;
    final navClearance = MediaQuery.paddingOf(context).bottom + 84;
    final provider = ref.watch(libraryProvider);
    // View-all is in-tab UI (not a route). Shell allows Library root to exit,
    // so intercept system/back-swipe here and return to rails instead.
    return PopScope(
      canPop: _viewAllSection == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_viewAllSection != null) _backToRails();
      },
      child: ScreenBackdrop(
        child: Stack(
          children: [
            SafeArea(bottom: false, child: _body(context, provider)),
            if (!provider.loading &&
                (provider.books.isNotEmpty || provider.mangas.isNotEmpty))
              Positioned(
                left: leftHanded ? 20 : null,
                right: leftHanded ? null : 20,
                bottom: navClearance,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.vertical,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                        );
                      },
                      child: provider.selectionMode &&
                              provider.selectedIds.isNotEmpty
                          ? Padding(
                              key: const ValueKey('hide-fab'),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AethelgardFab(
                                iconData: const MaterialIconData(
                                  Icons.visibility_off_outlined,
                                ),
                                tonal: true,
                                tooltip: 'Hide selected',
                                onPressed: () =>
                                    _hideSelected(context, provider),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-hide-fab')),
                    ),
                    _AethelgardFab(
                      iconData: AppIcons.add,
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
            emoji: '📚',
            title: 'You have not added a title',
            subtitle:
                'Add an extension repository to browse manga, or import an ebook to start reading.',
            primaryActionLabel: 'Browse Extensions',
            onPrimaryAction: () => context.pushNamed(Routes.extensions),
            secondaryActionLabel: 'Import ebook',
            onSecondaryAction: () => _showImportOptions(context),
            pillPrimary: true,
          ),
        ),
      ],
    );
  }

  // ── Normal content (scrolling includes spacer → header → rails/grid) ──

  void _openViewAll(_LibrarySection section) {
    setState(() => _viewAllSection = section);
  }

  void _backToRails() {
    setState(() => _viewAllSection = null);
  }

  Widget _combined(BuildContext context, LibraryState provider) {
    final viewingAll = _viewAllSection != null;
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () async {
        await _scanLocalCbzQuietly();
        await ref.read(libraryProvider.notifier).loadBooks();
        await _loadContinue();
        await _loadThumbnails();
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: OneHandSpacer()),
          SliverToBoxAdapter(child: _header(context, provider)),
          if (!viewingAll)
            ..._libraryRailsSlivers(context, provider)
          else ...[
            SliverToBoxAdapter(
              child: MediaRailViewAllBar(
                title: _viewAllSection == _LibrarySection.books
                    ? 'Books'
                    : 'Manga',
                countLabel: _viewAllSection == _LibrarySection.books
                    ? '${_visibleBooks(provider).length} titles'
                    : '${_visibleMangas(provider).length} titles',
                onBack: _backToRails,
              ),
            ),
            if (_viewAllSection == _LibrarySection.books)
              _BookShelf(
                key: const ValueKey('books-shelf'),
                books: _visibleBooks(provider),
                groups: _visibleBookGroups(provider),
                provider: provider,
                notifier: ref.read(libraryProvider.notifier),
                mangaThumbnails: _mangaThumbnails,
                showSourcePills: provider.showSourcePills,
                onOpen: (id) => openBookFromCollection(context, id),
                onBookLongPress: _showBookActions,
                onOpenGroup: (g) => _openGroup(context, g),
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
                mangas: _visibleMangas(provider),
                groups: _visibleMangaGroups(provider),
                provider: provider,
                notifier: ref.read(libraryProvider.notifier),
                extensionNames: provider.extensionNames,
                mangaThumbnails: _mangaThumbnails,
                showSourcePills: provider.showSourcePills,
                onOpen: (manga) => _openManga(context, manga),
                onOpenGroup: (g) => _openGroup(context, g),
              ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _libraryRailsSlivers(
    BuildContext context,
    LibraryState provider,
  ) {
    final books = _visibleBooks(provider);
    final mangas = _visibleMangas(provider);
    final groups = [
      ..._visibleBookGroups(provider),
      ..._visibleMangaGroups(provider),
    ];
    // Dedupe groups that contain both (same id).
    final seen = <int>{};
    final uniqueGroups = <LibraryGroupInfo>[];
    for (final g in groups) {
      if (seen.add(g.id)) uniqueGroups.add(g);
    }

    final continueCount = _continueItems.length;
    final slivers = <Widget>[];

    if (continueCount > 0) {
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Continue reading',
            subtitle: '$continueCount in progress',
            height: 200,
            itemCount: continueCount,
            itemBuilder: (context, i) {
              final item = _continueItems[i];
              final book = item.book;
              if (book != null) {
                return MediaRailCover(
                  width: 118,
                  child: StaggeredFadeScale(
                    index: i,
                    child: CatalogCoverCard(
                      title: book.title,
                      subtitle: '${(book.progress * 100).round()}% · Resume',
                      imageProvider: _bookCoverProvider(book),
                      variant: LibraryCardVariant.grid,
                      onTap: () => openBookFromCollection(context, book.id),
                    ),
                  ),
                );
              }
              final row = item.manga!;
              final manga = row.manga;
              return MediaRailCover(
                width: 118,
                child: StaggeredFadeScale(
                  index: i,
                  child: CatalogCoverCard(
                    title: manga.name,
                    subtitle: '${(row.progress * 100).round()}% · Resume',
                    imageProvider: _mangaCoverProvider(manga),
                    imageUrl: manga.imageUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openManga(context, manga),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (books.isNotEmpty) {
      final preview = books.take(12).toList();
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Books',
            subtitle: '${books.length} titles',
            onViewAll: () => _openViewAll(_LibrarySection.books),
            itemCount: preview.length,
            itemBuilder: (context, i) {
              final book = preview[i];
              return MediaRailCover(
                child: StaggeredFadeScale(
                  index: i,
                  child: CatalogCoverCard(
                    title: book.title,
                    subtitle: book.author,
                    imageProvider: _bookCoverProvider(book),
                    variant: LibraryCardVariant.grid,
                    onTap: () => openBookFromCollection(context, book.id),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (mangas.isNotEmpty) {
      final preview = mangas.take(12).toList();
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Manga',
            subtitle: '${mangas.length} titles',
            onViewAll: () => _openViewAll(_LibrarySection.manga),
            itemCount: preview.length,
            itemBuilder: (context, i) {
              final manga = preview[i];
              return MediaRailCover(
                child: StaggeredFadeScale(
                  index: i,
                  child: CatalogCoverCard(
                    title: manga.name,
                    subtitle: manga.author,
                    imageProvider: _mangaCoverProvider(manga),
                    imageUrl: manga.imageUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openManga(context, manga),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (uniqueGroups.isNotEmpty) {
      final preview = uniqueGroups.take(10).toList();
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Collections',
            subtitle: '${uniqueGroups.length} groups',
            // Match Books/Manga rail height so the fan stack can breathe like
            // the Collections grid (not a cramped grey list tile).
            height: 200,
            onViewAll: () => context.pushNamed(Routes.collections),
            itemCount: preview.length,
            itemBuilder: (context, i) {
              final g = preview[i];
              final covers = _groupCovers(g, provider);
              return MediaRailCover(
                width: 128,
                child: StaggeredFadeScale(
                  index: i,
                  child: LibraryGroupStackCard(
                    groupId: g.id,
                    name: g.name,
                    memberCount: g.members.length,
                    covers: covers,
                    onTap: () => _openGroup(context, g),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (slivers.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: MediaRailEmptyHint(
            message: 'Your library will show up here as rails once you add titles.',
          ),
        ),
      );
    }

    return slivers;
  }

  ImageProvider? _bookCoverProvider(Book book) {
    final path = book.coverPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return FileImage(File(path));
    }
    return null;
  }

  ImageProvider? _mangaCoverProvider(Manga manga) {
    final custom = manga.customCoverPath;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      return FileImage(File(custom));
    }
    final thumb = _mangaThumbnails[manga.id];
    if (thumb != null && thumb.isNotEmpty && File(thumb).existsSync()) {
      return FileImage(File(thumb));
    }
    final url = manga.imageUrl?.trim();
    if (url != null &&
        url.isNotEmpty &&
        !url.startsWith('http') &&
        File(url).existsSync()) {
      return FileImage(File(url));
    }
    return null;
  }

  List<GroupCoverSlot> _groupCovers(
    LibraryGroupInfo g,
    LibraryState provider,
  ) {
    final booksById = {for (final b in provider.books) b.id: b};
    final mangasById = {for (final m in provider.mangas) m.id: m};
    final slots = <GroupCoverSlot>[];
    for (final m in g.orderedMembers.take(3)) {
      if (m.isBook) {
        final book = booksById[m.itemId];
        if (book == null) continue;
        slots.add(
          GroupCoverSlot(
            title: book.title,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: _bookCoverProvider(book),
          ),
        );
      } else {
        final manga = mangasById[m.itemId];
        if (manga == null) continue;
        slots.add(
          GroupCoverSlot(
            title: manga.name,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: _mangaCoverProvider(manga),
          ),
        );
      }
    }
    return slots;
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _header(BuildContext context, LibraryState provider) {
    final c = context.colors;
    if (provider.selectionMode) {
      final hasBooks = provider.selectedIds.any((k) => k.startsWith('b:'));
      final hasManga = provider.selectedIds.any((k) => k.startsWith('m:'));
      final inMangaOnly = _viewAllSection == _LibrarySection.manga;
      final inBooksOnly = _viewAllSection == _LibrarySection.books;
      final showExport = hasBooks && !inMangaOnly;
      final showMerge = hasManga &&
          !inBooksOnly &&
          _selectedMangaPair(provider) != null;
      final showGroup = provider.selectedIds.length >= 2;
      return LibraryHeader(
        title: '${provider.selectedIds.length} selected',
        actions: [
          if (showGroup)
            IconButtonRound(
              icon: Icons.layers_outlined,
              size: 38,
              variant: IconButtonVariant.tonal,
              iconColor: c.accent,
              tooltip: 'Create group',
              onPressed: () => _createGroupFromSelection(context),
            ),
          if (showMerge)
            IconButtonRound(
              icon: Icons.merge_type_rounded,
              size: 38,
              variant: IconButtonVariant.tonal,
              iconColor: c.accent,
              tooltip: 'Merge duplicates',
              onPressed: () => _mergeSelectedManga(context, provider),
            ),
          IconButtonRound(
            icon: Icons.select_all_rounded,
            size: 38,
            variant: IconButtonVariant.tonal,
            iconColor: c.textSecondary,
            tooltip: 'Select all',
            onPressed: () => _selectAllInView(provider),
          ),
          if (showExport)
            IconButtonRound(
              icon: Icons.folder_copy_outlined,
              size: 38,
              variant: IconButtonVariant.tonal,
              iconColor: c.accent,
              tooltip: 'Export ebooks',
              onPressed: () => _exportSelectedEbooks(context, provider),
            ),
          IconButtonRound(
            icon: Icons.delete_outline,
            size: 38,
            variant: IconButtonVariant.tonal,
            iconColor: const Color(0xFFC44C4C),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, provider),
          ),
          IconButtonRound(
            icon: Icons.close,
            size: 38,
            variant: IconButtonVariant.tonal,
            tooltip: 'Cancel',
            onPressed: ref.read(libraryProvider.notifier).clearSelection,
          ),
        ],
      );
    }
    return LibraryHeader(
      title: ref.watch(userProfileProvider).libraryTitle,
      subtitle: _viewAllSection == null
          ? '${provider.books.length} books · ${provider.mangas.length} manga'
          : (_viewAllSection == _LibrarySection.books
              ? '${provider.books.length} books'
              : '${provider.mangas.length} manga'),
      titleFontSize: 28,
      titleFontWeight: FontWeight.w600,
      onTitleLongPress: () => openHiddenLibrary(context, ref),
      actions: [
        IconButtonRound(
          iconData: AppIcons.search,
          size: 44,
          variant: IconButtonVariant.plain,
          tooltip: 'Search library',
          onPressed: () => context.pushNamed(Routes.search),
        ),
        IconButtonRound(
          iconData: AppIcons.grid,
          size: 44,
          variant: IconButtonVariant.plain,
          tooltip: 'Library layout',
          onPressed: _showLayoutSheet,
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButtonRound(
              icon: Icons.tune_rounded,
              size: 44,
              variant: IconButtonVariant.plain,
              tooltip: 'Filter and sort library',
              onPressed: _showFilterSheet,
            ),
            if (_filters.values.any((mode) => mode != _FilterMode.none) ||
                _selectedCategoryId != null ||
                _bookSearchCtrl.text.trim().isNotEmpty ||
                _mangaSearchCtrl.text.trim().isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
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
      ],
    );
  }

  // ── Layout sheet ────────────────────────────────────────────────────

  void _showLayoutSheet() {
    LibraryLayoutSheet.show(context);
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

  List<Book> _visibleBooks(LibraryState provider) {
    final grouped = provider.groupedMemberKeys;
    final books = provider.books
        .where((b) => !grouped.contains('b:${b.id}'))
        .toList();
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

  List<Manga> _visibleMangas(LibraryState provider) {
    final grouped = provider.groupedMemberKeys;
    final mangas = provider.mangas
        .where((m) => !grouped.contains('m:${m.id}'))
        .toList();
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
              ...manga.alternateTitles,
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

  List<LibraryGroupInfo> _visibleBookGroups(LibraryState provider) {
    final q = _bookSearchCtrl.text.trim().toLowerCase();
    return provider.groups.where((g) {
      if (!g.hasBooks) return false;
      if (q.isEmpty) return true;
      return g.name.toLowerCase().contains(q);
    }).toList();
  }

  List<LibraryGroupInfo> _visibleMangaGroups(LibraryState provider) {
    final q = _mangaSearchCtrl.text.trim().toLowerCase();
    return provider.groups.where((g) {
      if (!g.hasManga) return false;
      if (q.isEmpty) return true;
      return g.name.toLowerCase().contains(q);
    }).toList();
  }

  /// Select-all scoped to the visible shelf (books / manga / both on home).
  void _selectAllInView(LibraryState provider) {
    final includeBooks = _viewAllSection != _LibrarySection.manga;
    final includeManga = _viewAllSection != _LibrarySection.books;
    ref.read(libraryProvider.notifier).selectAll(
          books: includeBooks,
          mangas: includeManga,
        );
  }

  Future<void> _createGroupFromSelection(BuildContext context) async {
    final c = context.colors;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _CreateGroupNameDialog(colors: c),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      await ref.read(libraryProvider.notifier).createGroupFromSelection(name);
      if (!context.mounted) return;
      StashToast.show(
        context,
        message: 'Group “$name” created',
        icon: Icons.layers_outlined,
      );
    } catch (e) {
      if (!context.mounted) return;
      StashToast.show(
        context,
        message: '$e',
        icon: Icons.error_outline,
      );
    }
  }

  /// Returns exactly two selected library manga, else null.
  (Manga, Manga)? _selectedMangaPair(LibraryState provider) {
    final ids = <int>[];
    for (final key in provider.selectedIds) {
      if (!key.startsWith('m:')) continue;
      final id = int.tryParse(key.substring(2));
      if (id != null) ids.add(id);
    }
    if (ids.length != 2) return null;
    Manga? a;
    Manga? b;
    for (final m in provider.mangas) {
      if (m.id == ids[0]) a = m;
      if (m.id == ids[1]) b = m;
    }
    if (a == null || b == null) return null;
    return (a, b);
  }

  Future<void> _mergeSelectedManga(
    BuildContext context,
    LibraryState provider,
  ) async {
    final pair = _selectedMangaPair(provider);
    if (pair == null) return;
    final keep = pair.$1;
    final absorb = pair.$2;
    final repos = ref.read(repositoriesProvider);
    final merge = MergeMangaUseCase(repos);
    final keepLabel = await merge.sourceLabel(keep);
    final absorbLabel = await merge.sourceLabel(absorb);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge duplicates?'),
        content: Text(
          'Keep "${keep.name}" and absorb "${absorb.name}" '
          '($absorbLabel). The duplicate leaves the library.\n\n'
          'Keeping source: $keepLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await merge.invoke(keep: keep, absorb: absorb);
      if (!context.mounted) return;
      ref.read(libraryProvider.notifier).clearSelection();
      await ref.read(libraryProvider.notifier).loadBooks();
      if (!context.mounted) return;
      StashToast.show(
        context,
        message: 'Merged into "${keep.name}"',
        icon: Icons.merge_type_rounded,
      );
    } on MergeValidationException catch (e) {
      if (!context.mounted) return;
      StashToast.show(context, message: e.message, icon: Icons.error_outline);
    } catch (e) {
      if (!context.mounted) return;
      StashToast.show(context, message: '$e', icon: Icons.error_outline);
    }
  }

  void _openGroup(BuildContext context, LibraryGroupInfo group) {
    showLibraryGroupModal(
      context: context,
      ref: ref,
      group: group,
      mangaThumbnails: _mangaThumbnails,
      onOpenBook: (book) => openBookFromCollection(context, book.id),
      onOpenManga: (manga) => _openManga(context, manga),
    );
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

  Future<void> _exportSelectedEbooks(
    BuildContext context,
    LibraryState provider,
  ) async {
    final books = <Book>[];
    for (final key in provider.selectedIds) {
      if (!key.startsWith('b:')) continue;
      final id = int.tryParse(key.substring(2));
      if (id == null) continue;
      for (final book in provider.books) {
        if (book.id == id) {
          books.add(book);
          break;
        }
      }
    }
    final result = await exportEbooksToPickedFolder(context, books: books);
    if (result != null && result.exported > 0 && context.mounted) {
      ref.read(libraryProvider.notifier).clearSelection();
    }
  }

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
      if (mounted) await _loadContinue();
    }
  }

  Future<void> _hideSelected(
    BuildContext context,
    LibraryState provider,
  ) async {
    final n = provider.selectedIds.length;
    if (n == 0) return;
    final count = await ref.read(libraryProvider.notifier).hideSelected();
    if (!mounted) return;
    await _loadContinue();
    if (!context.mounted) return;
    StashToast.show(
      context,
      message: count == 1
          ? '1 title hidden — long-press Library title to open'
          : '$count titles hidden — long-press Library title to open',
      icon: Icons.visibility_off_outlined,
    );
  }

  void _showImportOptions(BuildContext context) {
    ImportSheet.show(
      context,
      options: [
        ImportOption(
          icon: Icons.file_present_outlined,
          title: 'Import file',
          subtitle: 'EPUB, PDF, TXT, or Markdown',
          onTap: () => _importFile(context),
        ),
        ImportOption(
          icon: Icons.folder_zip_outlined,
          title: 'Import CBZ folder',
          subtitle: 'One series folder = one manga with chapters',
          onTap: () => _importCbzFolder(context),
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

  Future<void> _scanLocalCbzQuietly() async {
    final path = await LocalCbzPrefs.folderPath();
    if (path == null) return;
    try {
      await LocalCbzScanner(ref.read(repositoriesProvider)).scanFolder(path);
    } catch (_) {}
  }

  Future<void> _importCbzFolder(BuildContext context) async {
    try {
      if (AndroidStorageAccess.needsAllFilesAccess('/storage/emulated/0') &&
          !await AndroidStorageAccess.hasAllFilesAccess()) {
        await AndroidStorageAccess.requestAllFilesAccess();
        if (!context.mounted) return;
        StashToast.show(
          context,
          message: 'Grant All files access, then try again',
          icon: Icons.info_outline,
        );
        return;
      }
      final picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose local manga folder',
      );
      if (picked == null || !context.mounted) return;
      if (AndroidStorageAccess.needsAllFilesAccess(picked) &&
          !await AndroidStorageAccess.hasAllFilesAccess()) {
        if (!context.mounted) return;
        StashToast.show(
          context,
          message:
              'Android blocked this folder. Grant All files access, then try again.',
          icon: Icons.error_outline,
        );
        return;
      }

      await LocalCbzPrefs.setFolderPath(picked);
      if (!context.mounted) return;
      StashToast.show(context, message: 'Scanning CBZ folder…');

      final result = await LocalCbzScanner(
        ref.read(repositoriesProvider),
      ).scanFolder(picked, forceInLibrary: true);
      await ref.read(libraryProvider.notifier).loadBooks();
      if (!context.mounted) return;

      if (!result.ok) {
        StashToast.show(
          context,
          message: result.error ?? 'Scan failed',
          icon: Icons.error_outline,
        );
        return;
      }
      StashToast.show(
        context,
        message: result.seriesUpserted == 0
            ? 'No CBZ series found'
            : 'Added ${result.seriesUpserted} series'
                '${result.chaptersAdded > 0 ? ', ${result.chaptersAdded} new chapters' : ''}',
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      if (context.mounted) {
        StashToast.show(
          context,
          message: 'Import failed: $e',
          icon: Icons.error_outline,
        );
      }
    }
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
          'pdf',
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
      final pickedPath = result.files.single.path!;
      final ebookSvc = EbookService();
      final filePath = await ebookSvc.persistImportCopy(pickedPath);
      final showMobiLoader = _isMobiFile(filePath);
      if (showMobiLoader && mounted) {
        setState(() => _importingFile = true);
      }
      final repos = ref.read(repositoriesProvider);
      final ln = ref.read(libraryProvider.notifier);
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
      if (filePath.toLowerCase().endsWith('.epub')) {
        await KomaPackageStore.compileEpub(
          bookId: bookId,
          epubPath: filePath,
        );
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
        return Material(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
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

/// Unified Continue reading entry — books and manga sorted by [lastReadAt].
class _ContinueItem {
  const _ContinueItem._({
    required this.lastReadAt,
    this.book,
    this.manga,
  });

  factory _ContinueItem.book(Book book, DateTime lastReadAt) =>
      _ContinueItem._(lastReadAt: lastReadAt, book: book);

  factory _ContinueItem.manga(InProgressManga manga, DateTime lastReadAt) =>
      _ContinueItem._(lastReadAt: lastReadAt, manga: manga);

  final DateTime lastReadAt;
  final Book? book;
  final InProgressManga? manga;
}

/// Owns its [TextEditingController] so cancel/create don't dispose it while
/// the dialog route is still animating out.
class _CreateGroupNameDialog extends StatefulWidget {
  const _CreateGroupNameDialog({required this.colors});

  final KomaColors colors;

  @override
  State<_CreateGroupNameDialog> createState() => _CreateGroupNameDialogState();
}

class _CreateGroupNameDialogState extends State<_CreateGroupNameDialog> {
  late final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('New group', style: TextStyle(color: c.textPrimary)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Group name',
          labelStyle: TextStyle(color: c.textSecondary),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textTertiary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text('Create', style: TextStyle(color: c.accent)),
        ),
      ],
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
    // Sheet sits in the tab navigator while [AppBottomNav] stays visible
    // (extendBody shell) — clear the 72px bar + system inset.
    final bottomClearance =
        72.0 + MediaQuery.paddingOf(context).bottom + 20;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomClearance),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButtonRound(
                  icon: Icons.close_rounded,
                  size: 36,
                  variant: IconButtonVariant.filled,
                  backgroundColor: c.surfaceMuted,
                  iconColor: c.textSecondary,
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
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
  final List<LibraryGroupInfo> groups;
  final LibraryState provider;
  final LibraryNotifier notifier;
  final Map<int, String?> mangaThumbnails;
  final ValueChanged<int> onOpen;
  final ValueChanged<Book> onBookLongPress;
  final ValueChanged<LibraryGroupInfo> onOpenGroup;
  final bool showSourcePills;

  const _BookShelf({
    super.key,
    required this.books,
    required this.groups,
    required this.provider,
    required this.notifier,
    required this.mangaThumbnails,
    required this.onOpen,
    required this.onBookLongPress,
    required this.onOpenGroup,
    this.showSourcePills = true,
  });

  int get _total => groups.length + books.length;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: EmptyState(
            icon: AppIcons.search,
            emoji: '🔎',
            title: 'No books found',
            subtitle: 'Try another title, author, genre, or format.',
          ),
        ),
      );
    }
    final sw = Stopwatch()..start();
    late final Widget result;
    // Card style is the source of truth (layout sheet). List style uses a
    // vertical shelf; everything else uses the column grid.
    if (provider.cardVariant != LibraryCardVariant.list) {
      final variant = provider.cardVariant;
      result = SliverPadding(
        padding: CatalogCardLayout.paddingFor(variant),
        sliver: SliverGrid(
          gridDelegate: CatalogCardLayout.gridDelegate(
            columns: provider.gridColumns,
            variant: variant,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => StaggeredFadeScale(
              index: i,
              child: _tile(ctx, i, variant),
            ),
            childCount: _total,
          ),
        ),
      );
      BenchmarkLogger.log(
        'book_shelf_build',
        'variant=${variant.name} cols=${provider.gridColumns} count=$_total elapsed=${sw.elapsedMicroseconds}us',
      );
      return result;
    }
    result = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, index) {
          if (index.isOdd) return const SizedBox(height: 8);
          final i = index ~/ 2;
          return StaggeredFadeScale(
            index: i,
            child: _tile(ctx, i, LibraryCardVariant.list),
          );
        }, childCount: _total * 2 - 1),
      ),
    );
    BenchmarkLogger.log(
      'book_shelf_build',
      'variant=list count=$_total elapsed=${sw.elapsedMicroseconds}us',
    );
    return result;
  }

  Widget _tile(BuildContext context, int i, LibraryCardVariant variant) {
    if (i < groups.length) {
      final group = groups[i];
      return LibraryGroupStackCard(
        groupId: group.id,
        name: group.name,
        memberCount: group.members.length,
        covers: _groupCovers(context, group),
        listLayout: variant == LibraryCardVariant.list,
        onTap: () => onOpenGroup(group),
      );
    }
    final book = books[i - groups.length];
    return LibraryBookCard(
      book: book,
      variant: variant,
      selected: provider.selectedIds.contains('b:${book.id}'),
      selectionMode: provider.selectionMode,
      showSourcePills: provider.showSourcePills,
      onTap: () => provider.selectionMode
          ? notifier.toggleSelection('b:${book.id}')
          : onOpen(book.id),
      onLongPress: () => provider.selectionMode
          ? notifier.toggleSelection('b:${book.id}')
          : onBookLongPress(book),
    );
  }

  List<GroupCoverSlot> _groupCovers(
    BuildContext context,
    LibraryGroupInfo group,
  ) {
    final booksById = {for (final b in provider.books) b.id: b};
    final mangasById = {for (final m in provider.mangas) m.id: m};
    final slots = <GroupCoverSlot>[];
    for (final m in group.orderedMembers) {
      if (m.isBook) {
        final book = booksById[m.itemId];
        if (book == null) continue;
        final path = book.coverPath;
        slots.add(
          GroupCoverSlot(
            title: book.title,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: path != null && path.isNotEmpty && File(path).existsSync()
                ? FileImage(File(path))
                : null,
          ),
        );
      } else {
        final manga = mangasById[m.itemId];
        if (manga == null) continue;
        final local = mangaThumbnails[manga.id];
        ImageProvider? image;
        if (local != null && local.isNotEmpty && File(local).existsSync()) {
          image = FileImage(File(local));
        } else if (manga.imageUrl != null && manga.imageUrl!.isNotEmpty) {
          image = cachedCover(manga.imageUrl!);
        }
        slots.add(
          GroupCoverSlot(
            title: manga.name,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: image,
          ),
        );
      }
    }
    return slots;
  }
}

class _MangaShelf extends StatelessWidget {
  final List<Manga> mangas;
  final List<LibraryGroupInfo> groups;
  final LibraryState provider;
  final LibraryNotifier notifier;
  final ValueChanged<Manga> onOpen;
  final ValueChanged<LibraryGroupInfo> onOpenGroup;
  final Map<int, String?> mangaThumbnails;
  final Map<String, String> extensionNames;
  final bool showSourcePills;

  const _MangaShelf({
    super.key,
    required this.mangas,
    required this.groups,
    required this.provider,
    required this.notifier,
    required this.onOpen,
    required this.onOpenGroup,
    this.mangaThumbnails = const {},
    this.extensionNames = const {},
    this.showSourcePills = true,
  });

  int get _total => groups.length + mangas.length;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: EmptyState(
            icon: AppIcons.search,
            emoji: '🔎',
            title: 'No manga found',
            subtitle: 'Try another title, author, source, or genre.',
          ),
        ),
      );
    }
    final sw = Stopwatch()..start();
    late final Widget result;
    if (provider.cardVariant != LibraryCardVariant.list) {
      final variant = provider.cardVariant;
      result = SliverPadding(
        padding: CatalogCardLayout.paddingFor(variant),
        sliver: SliverGrid(
          gridDelegate: CatalogCardLayout.gridDelegate(
            columns: provider.gridColumns,
            variant: variant,
          ),
          delegate: SliverChildBuilderDelegate((ctx, i) {
            return StaggeredFadeScale(
              index: i,
              child: _tile(ctx, i, variant),
            );
          }, childCount: _total),
        ),
      );
      BenchmarkLogger.log(
        'manga_shelf_build',
        'variant=${variant.name} cols=${provider.gridColumns} count=$_total elapsed=${sw.elapsedMicroseconds}us',
      );
      return result;
    }
    result = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, index) {
          if (index.isOdd) return const SizedBox(height: 8);
          final i = index ~/ 2;
          return StaggeredFadeScale(
            index: i,
            child: _tile(ctx, i, LibraryCardVariant.list),
          );
        }, childCount: _total * 2 - 1),
      ),
    );
    BenchmarkLogger.log(
      'manga_shelf_build',
      'variant=list count=$_total elapsed=${sw.elapsedMicroseconds}us',
    );
    return result;
  }

  Widget _tile(BuildContext context, int i, LibraryCardVariant variant) {
    if (i < groups.length) {
      final group = groups[i];
      return LibraryGroupStackCard(
        groupId: group.id,
        name: group.name,
        memberCount: group.members.length,
        covers: _groupCovers(group),
        listLayout: variant == LibraryCardVariant.list,
        onTap: () => onOpenGroup(group),
      );
    }
    final manga = mangas[i - groups.length];
    if (variant == LibraryCardVariant.list) {
      return _MangaLibraryRow(
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
      );
    }
    return _MangaLibraryCard(
      manga: manga,
      newChapterCount: provider.newChapters[manga.id] ?? 0,
      localImagePath: mangaThumbnails[manga.id],
      selected: provider.selectedIds.contains('m:${manga.id}'),
      selectionMode: provider.selectionMode,
      extensionName: extensionNames[manga.sourceId] ?? manga.sourceId,
      showSourcePills: showSourcePills,
      showUnreadBadge: provider.showUnreadBadge,
      showContinueButton: provider.showContinueButton,
      variant: variant,
      onContinue: () => onOpen(manga),
      onTap: () => provider.selectionMode
          ? notifier.toggleSelection('m:${manga.id}')
          : onOpen(manga),
      onLongPress: () => notifier.toggleSelection('m:${manga.id}'),
    );
  }

  List<GroupCoverSlot> _groupCovers(LibraryGroupInfo group) {
    final booksById = {for (final b in provider.books) b.id: b};
    final mangasById = {for (final m in provider.mangas) m.id: m};
    final slots = <GroupCoverSlot>[];
    for (final m in group.orderedMembers) {
      if (m.isBook) {
        final book = booksById[m.itemId];
        if (book == null) continue;
        final path = book.coverPath;
        slots.add(
          GroupCoverSlot(
            title: book.title,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: path != null && path.isNotEmpty && File(path).existsSync()
                ? FileImage(File(path))
                : null,
          ),
        );
      } else {
        final manga = mangasById[m.itemId];
        if (manga == null) continue;
        final local = mangaThumbnails[manga.id];
        ImageProvider? image;
        if (local != null && local.isNotEmpty && File(local).existsSync()) {
          image = FileImage(File(local));
        } else if (manga.imageUrl != null && manga.imageUrl!.isNotEmpty) {
          image = cachedCover(manga.imageUrl!);
        }
        slots.add(
          GroupCoverSlot(
            title: manga.name,
            memberKey: m.memberKey,
            readingOrder: m.readingOrder,
            image: image,
          ),
        );
      }
    }
    return slots;
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
  final bool showUnreadBadge;
  final bool showContinueButton;
  final VoidCallback? onContinue;

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
    this.showUnreadBadge = true,
    this.showContinueButton = false,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final headers = ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
    final coverOnly = variant == LibraryCardVariant.coverOnly;
    if (variant == LibraryCardVariant.overlay || coverOnly) {
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
                if (!coverOnly)
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
                if (showUnreadBadge && newChapterCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _NewChapterBadge(count: newChapterCount),
                  ),
                if (showContinueButton &&
                    newChapterCount > 0 &&
                    onContinue != null &&
                    !selectionMode)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _ContinueFab(onTap: onContinue!),
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
                if (!coverOnly)
                  Positioned(
                    left: 8,
                    right: showContinueButton && newChapterCount > 0 ? 48 : 8,
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
                if (showUnreadBadge && newChapterCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _NewChapterBadge(count: newChapterCount),
                  ),
                if (showContinueButton &&
                    newChapterCount > 0 &&
                    onContinue != null &&
                    !selectionMode)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _ContinueFab(onTap: onContinue!),
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
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 16 / 12,
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
class _ContinueFab extends StatelessWidget {
  const _ContinueFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.accent,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.play_arrow_rounded, size: 18, color: c.onAccent),
        ),
      ),
    );
  }
}

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
  final bool tonal;
  final String? tooltip;

  const _AethelgardFab({
    required this.iconData,
    this.onPressed,
    this.tonal = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fab = AnimatedPress(
      onTap: onPressed,
      scaleDown: 0.90,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: tonal ? c.surface : c.accent,
          shape: BoxShape.circle,
          border: tonal ? Border.all(color: c.border, width: 0.5) : null,
          boxShadow: tonal
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppSpacing.fabGlow(accent: c.accent),
        ),
        child: Center(
          child: AppIcon(
            data: iconData,
            size: 26,
            color: tonal ? c.textPrimary : c.onAccent,
          ),
        ),
      ),
    );
    if (tooltip == null) return fab;
    return Tooltip(message: tooltip!, child: fab);
  }
}
