import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/app_lock_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/hidden_titles_prefs.dart';
import '../../core/services/security_prefs.dart';
import '../../core/utils/image_cache.dart';
import '../../features/reader/reader_settings_sheet.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/toast.dart';
import 'book_detail_screen.dart';

/// Secret shelf of hidden manga/books. Open via long-press on the Library
/// title after unlocking with App Lock.
class HiddenLibraryScreen extends ConsumerStatefulWidget {
  const HiddenLibraryScreen({super.key});

  @override
  ConsumerState<HiddenLibraryScreen> createState() =>
      _HiddenLibraryScreenState();
}

class _HiddenLibraryScreenState extends ConsumerState<HiddenLibraryScreen> {
  List<Manga> _mangas = [];
  List<Book> _books = [];
  final Map<int, String?> _mangaThumbnails = {};
  bool _loading = true;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repos = ref.read(repositoriesProvider);
    final allManga = await repos.manga.getMangasInLibrary();
    final allBooks = await repos.books.getBooks();
    final hiddenBooks = await HiddenTitlesPrefs.hiddenBookIds();
    final mangas = [
      for (final m in allManga)
        if (ViewerFlags.isHidden(m.viewerFlags)) m,
    ];
    final books = [
      for (final b in allBooks)
        if (hiddenBooks.contains(b.id)) b,
    ];
    final thumbs = await _loadThumbnails(mangas);
    if (!mounted) return;
    final validKeys = {
      for (final m in mangas) 'm:${m.id}',
      for (final b in books) 'b:${b.id}',
    };
    setState(() {
      _mangas = mangas;
      _books = books;
      _mangaThumbnails
        ..clear()
        ..addAll(thumbs);
      _selectedIds.removeWhere((k) => !validKeys.contains(k));
      if (_selectedIds.isEmpty) _selectionMode = false;
      _loading = false;
    });
  }

  Future<Map<int, String?>> _loadThumbnails(List<Manga> mangas) async {
    try {
      final appDir = await AppStorage.documents();
      final thumbDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbDir.exists()) return {};
      final paths = <int, String?>{};
      for (final manga in mangas) {
        final file = File('${thumbDir.path}/${manga.id}.jpg');
        if (await file.exists()) paths[manga.id] = file.path;
      }
      return paths;
    } catch (_) {
      return {};
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedIds.contains(key)) {
        _selectedIds.remove(key);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(key);
        _selectionMode = true;
      }
    });
  }

  Future<void> _unhideManga(Manga m, {bool silent = false}) async {
    final repos = ref.read(repositoriesProvider);
    await repos.manga.updateMangaExtras(
      m.id,
      viewerFlags: ViewerFlags.setHidden(m.viewerFlags, false),
    );
    if (!silent && mounted) {
      ref.read(libraryProvider.notifier).loadBooks();
      ref.read(historyRevisionProvider.notifier).bump();
      StashToast.show(
        context,
        message: 'Visible in library again',
        icon: Icons.visibility_outlined,
      );
      await _load();
    }
  }

  Future<void> _unhideBook(Book b, {bool silent = false}) async {
    await ref.read(hiddenTitlesProvider.notifier).setBookHidden(b.id, false);
    if (!silent && mounted) {
      ref.read(libraryProvider.notifier).loadBooks();
      ref.read(historyRevisionProvider.notifier).bump();
      StashToast.show(
        context,
        message: 'Visible in library again',
        icon: Icons.visibility_outlined,
      );
      await _load();
    }
  }

  Future<void> _unhideSelected() async {
    final keys = _selectedIds.toList();
    if (keys.isEmpty) return;
    final mangaById = {for (final m in _mangas) m.id: m};
    final bookById = {for (final b in _books) b.id: b};
    var count = 0;
    for (final key in keys) {
      if (key.startsWith('m:')) {
        final id = int.tryParse(key.substring(2));
        final m = id == null ? null : mangaById[id];
        if (m == null) continue;
        await _unhideManga(m, silent: true);
        count++;
      } else if (key.startsWith('b:')) {
        final id = int.tryParse(key.substring(2));
        final b = id == null ? null : bookById[id];
        if (b == null) continue;
        await _unhideBook(b, silent: true);
        count++;
      }
    }
    if (!mounted) return;
    _clearSelection();
    ref.read(libraryProvider.notifier).loadBooks();
    ref.read(historyRevisionProvider.notifier).bump();
    await _load();
    if (!mounted) return;
    StashToast.show(
      context,
      message: count == 1
          ? '1 title visible in library again'
          : '$count titles visible in library again',
      icon: Icons.visibility_outlined,
    );
  }

  void _openManga(Manga m) {
    context.pushNamed(
      Routes.mangaDetail,
      extra: (
        sourceId: m.sourceId,
        url: m.url,
        title: m.name,
        manga: m,
        memo: m.memo,
      ),
    );
  }

  void _openBook(Book b) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookDetailScreen(bookId: b.id),
      ),
    );
  }

  ImageProvider? _mangaCover(Manga m) {
    final local = _mangaThumbnails[m.id];
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return FileImage(File(local));
    }
    if (m.imageUrl != null && m.imageUrl!.isNotEmpty) {
      return cachedCover(m.imageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final leftHanded = ref.watch(themeProvider).handMode == HandMode.left;
    final variant = CatalogCardLayout.gridVariant(library.cardVariant);
    final columns = library.gridColumns;
    final total = _mangas.length + _books.length;
    final showUnhideFab = _selectionMode && _selectedIds.isNotEmpty;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectionMode) _clearSelection();
      },
      child: ScreenBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              SafeArea(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: OneHandSpacer()),
                    SliverToBoxAdapter(
                      child: _selectionMode
                          ? LibraryHeader(
                              title: '${_selectedIds.length} selected',
                              showBackButton: true,
                              onBack: _clearSelection,
                            )
                          : LibraryHeader(
                              title: 'Hidden',
                              subtitle: total == 0
                                  ? 'Secret shelf'
                                  : '$total title${total == 1 ? '' : 's'} · long-press to select',
                              showBackButton: true,
                            ),
                    ),
                    if (_loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (total == 0)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: AppIcons.library,
                          emoji: '🤫',
                          title: 'Nothing hidden',
                          subtitle:
                              'Hide a title from its ⋮ menu. It stays readable here.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: CatalogCardLayout.paddingFor(variant).add(
                          EdgeInsets.only(bottom: showUnhideFab ? 100 : 24),
                        ),
                        sliver: SliverGrid(
                          gridDelegate: CatalogCardLayout.gridDelegate(
                            columns: columns,
                            variant: variant,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              if (i < _mangas.length) {
                                final m = _mangas[i];
                                final key = 'm:${m.id}';
                                final ext = library.extensionNames[m.sourceId] ??
                                    m.sourceId;
                                return CatalogCoverCard(
                                  title: m.name,
                                  subtitle: ext,
                                  badge: 'Manga',
                                  imageProvider: _mangaCover(m),
                                  imageUrl: m.imageUrl,
                                  variant: variant,
                                  selected: _selectedIds.contains(key),
                                  selectionMode: _selectionMode,
                                  onTap: () => _selectionMode
                                      ? _toggleSelection(key)
                                      : _openManga(m),
                                  onLongPress: () => _toggleSelection(key),
                                );
                              }
                              final b = _books[i - _mangas.length];
                              final key = 'b:${b.id}';
                              return LibraryBookCard(
                                book: b,
                                variant: variant,
                                showSourcePills: library.showSourcePills,
                                selected: _selectedIds.contains(key),
                                selectionMode: _selectionMode,
                                onTap: () => _selectionMode
                                    ? _toggleSelection(key)
                                    : _openBook(b),
                                onLongPress: () => _toggleSelection(key),
                              );
                            },
                            childCount: total,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_loading && total > 0)
                Positioned(
                  left: leftHanded ? 20 : null,
                  right: leftHanded ? null : 20,
                  bottom: bottomPad,
                  child: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.85, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: showUnhideFab
                        ? _UnhideFab(
                            key: const ValueKey('unhide-fab'),
                            onPressed: _unhideSelected,
                          )
                        : const SizedBox.shrink(key: ValueKey('no-unhide-fab')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnhideFab extends StatelessWidget {
  const _UnhideFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: 'Unhide selected',
      child: AnimatedPress(
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
            child: Icon(
              Icons.visibility_outlined,
              size: 26,
              color: c.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Long-press Library title → require App Lock → open [HiddenLibraryScreen].
Future<void> openHiddenLibrary(BuildContext context, WidgetRef ref) async {
  final lockOn = ref.read(appLockEnabledProvider);
  if (!lockOn) {
    StashToast.show(
      context,
      message: 'Turn on App Lock in Settings → Security first',
      icon: Icons.lock_outline,
    );
    return;
  }

  final result = await AppLockService.authenticate(
    reason: 'Open hidden library',
  );
  if (!context.mounted) return;
  if (!result.success) {
    if (result.errorMessage != null &&
        result.errorMessage!.trim().isNotEmpty) {
      StashToast.show(
        context,
        message: result.errorMessage!,
        icon: Icons.lock_outline,
      );
    }
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const HiddenLibraryScreen(),
    ),
  );
}
