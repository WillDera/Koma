import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart' show routeObserver;
import '../../core/models/book.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/repositories/manga_repository.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';

/// Unified history row for date grouping (books + manga).
class _HistoryEntry {
  _HistoryEntry.book(Book book)
    : book = book,
      manga = null,
      when = book.updatedAt;

  _HistoryEntry.manga(InProgressManga manga)
    : book = null,
      manga = manga,
      when = manga.lastReadAt ?? manga.manga.updatedAt;

  final Book? book;
  final InProgressManga? manga;
  final DateTime when;
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with RouteAware {
  final ScrollController _scrollCtrl = ScrollController();

  List<Book> _books = [];
  List<InProgressManga> _mangaRows = [];
  bool _loading = true;
  int _lastSeenRevision = 0;

  /// Cover providers cached per manga id so tile rebuilds reuse the same
  /// [ImageProvider] instance instead of constructing a new one each build.
  final Map<int, ImageProvider> _coverCache = {};

  @override
  void initState() {
    super.initState();
    _lastSeenRevision = ref.read(historyRevisionProvider);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    // Watch the global history revision so we reload in real time when the
    // reader writes progress (shell-tab screens don't reliably get
    // RouteAware.didPopNext from root-level reader routes).
    final rev = ref.read(historyRevisionProvider);
    if (rev != _lastSeenRevision) {
      _lastSeenRevision = rev;
      _load();
    }
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repos = ref.read(repositoriesProvider);
    final results = await Future.wait([
      repos.books.getInProgressBooks(),
      repos.manga.getInProgressManga(),
    ]);
    _books = results[0] as List<Book>;
    _mangaRows = results[1] as List<InProgressManga>;
    _coverCache.clear();
    if (mounted) setState(() => _loading = false);
  }

  int get _totalCount => _books.length + _mangaRows.length;

  List<_HistoryEntry> get _entries {
    final out = <_HistoryEntry>[
      for (final b in _books) _HistoryEntry.book(b),
      for (final m in _mangaRows) _HistoryEntry.manga(m),
    ];
    out.sort((a, b) => b.when.compareTo(a.when));
    return out;
  }

  String _relativeDay(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat.MMMd().format(when);
  }

  Future<void> _clearProgress(Book book) async {
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear reading history?',
      content:
          'Remove "${book.title}" from your history. '
          'The book and its chapters will be kept.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    );
    if (confirmed != true) return;
    final repos = ref.read(repositoriesProvider);
    await repos.books.clearProgress(book.id);
    await _load();
  }

  Future<void> _clearMangaProgress(InProgressManga mangaRow) async {
    final name = mangaRow.manga.name;
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear reading history?',
      content:
          'Remove "$name" from your history. '
          'The manga will be kept in your library.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    );
    if (confirmed != true) return;
    final repos = ref.read(repositoriesProvider);
    await repos.manga.clearMangaChapterHistory(mangaRow.manga.id);
    await _load();
  }

  Future<void> _clearAll() async {
    if (_totalCount == 0) return;
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear all history?',
      content:
          'Remove all books and manga from your reading history. '
          'Your library items will be kept.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear all'),
        ),
      ],
    );
    if (confirmed != true) return;
    final repos = ref.read(repositoriesProvider);
    for (final book in List<Book>.from(_books)) {
      await repos.books.clearProgress(book.id);
    }
    for (final row in List<InProgressManga>.from(_mangaRows)) {
      await repos.manga.clearMangaChapterHistory(row.manga.id);
    }
    await _load();
  }

  void _openEntry(_HistoryEntry entry) {
    if (entry.book != null) {
      openBookFromCollection(context, entry.book!.id);
      return;
    }
    final manga = entry.manga!.manga;
    context.pushNamed(
      Routes.mangaDetail,
      extra: (
        sourceId: manga.sourceId,
        url: manga.url,
        title: manga.name,
        manga: manga,
        memo: manga.memo,
      ) as MangaDetailArgs,
    );
  }

  String _subtitleFor(_HistoryEntry entry) {
    if (entry.book != null) {
      final book = entry.book!;
      if (book.totalChapters > 0) {
        return 'Chapter ${book.currentChapterIndex + 1}';
      }
      final pct = (book.progress * 100).round();
      return '$pct% complete';
    }
    final row = entry.manga!;
    if (row.totalChapters > 0) {
      return '${row.readCount} / ${row.totalChapters} chapters';
    }
    final author = row.manga.author;
    if (author != null && author.isNotEmpty) return author;
    return 'In progress';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // React to reader progress writes in real time.
    ref.listen<int>(historyRevisionProvider, (prev, next) {
      if (next != _lastSeenRevision) {
        _lastSeenRevision = next;
        _load();
      }
    });

    if (_loading) {
      return ScreenBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: CircularProgressIndicator(color: c.accent),
          ),
        ),
      );
    }

    final entries = _entries;
    final grouped = <String, List<_HistoryEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(_relativeDay(e.when), () => []).add(e);
    }

    // Precompute global stagger indices so section builders stay pure.
    final staggerBase = <String, int>{};
    var nextStagger = 0;
    for (final section in grouped.entries) {
      staggerBase[section.key] = nextStagger;
      nextStagger += section.value.length;
    }

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surface,
          onRefresh: _load,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: OneHandSpacer()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your History',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Material(
                        color: c.surfaceMuted,
                        borderRadius: BorderRadius.circular(64),
                        child: InkWell(
                          onTap: _totalCount > 0 ? _clearAll : _load,
                          borderRadius: BorderRadius.circular(64),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _totalCount > 0
                                      ? Icons.delete_outline_rounded
                                      : Icons.refresh_rounded,
                                  size: 22,
                                  color: c.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _totalCount > 0 ? 'Clear' : 'Refresh',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (entries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: AppIcons.history,
                    emoji: '📚',
                    title: 'No history yet',
                    subtitle:
                        'Books and manga you\'re reading will appear here.',
                  ),
                )
              else
                for (final section in grouped.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(
                        section.key,
                        style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final entry = section.value[i];
                      final index = (staggerBase[section.key] ?? 0) + i;
                      return StaggeredFadeScale(
                        index: index,
                        child: _HistoryRow(
                          entry: entry,
                          subtitle: _subtitleFor(entry),
                          coverCache: _coverCache,
                          onTap: () => _openEntry(entry),
                          onLongPress: () {
                            if (entry.book != null) {
                              _clearProgress(entry.book!);
                            } else {
                              _clearMangaProgress(entry.manga!);
                            }
                          },
                        ),
                      );
                    }, childCount: section.value.length),
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.entry,
    required this.subtitle,
    required this.coverCache,
    required this.onTap,
    required this.onLongPress,
  });

  final _HistoryEntry entry;
  final String subtitle;
  final Map<int, ImageProvider> coverCache;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final title = entry.book?.title ?? entry.manga!.manga.name;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 58,
                height: 72,
                child: entry.book != null
                    ? BookCover(
                        book: entry.book!,
                        expand: true,
                        borderRadius: BorderRadius.circular(4),
                      )
                    : _MangaCover(
                        manga: entry.manga!.manga,
                        coverCache: coverCache,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 22 / 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textTertiary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaCover extends ConsumerWidget {
  const _MangaCover({
    required this.manga,
    required this.coverCache,
  });

  final Manga manga;
  final Map<int, ImageProvider> coverCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final custom = manga.customCoverPath;
    final imageUrl = manga.imageUrl;
    final headers =
        ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;

    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      return Image.file(File(custom), fit: BoxFit.cover);
    }

    ImageProvider? coverProvider;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final cached = coverCache[manga.id];
      if (cached != null) {
        coverProvider = cached;
      } else {
        coverProvider = cachedCover(
          imageUrl,
          headers: headers,
          width: 58,
          height: 72,
        );
        if (headers != null) coverCache[manga.id] = coverProvider;
      }
    }

    if (coverProvider != null) {
      return Image(
        image: coverProvider,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: c.iconWell),
      );
    }
    return ColoredBox(color: c.iconWell);
  }
}
