import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recommendation_engine/recommendation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/manga.dart';
import '../providers.dart';
import '../repositories/repositories.dart';
import '../services/hidden_titles_prefs.dart';
import '../services/user_profile.dart';
import '../../features/discover/explore_view_prefs.dart';
import '../../features/reader/reader_settings_sheet.dart' show ViewerFlags;
import 'library_hub_models.dart';
import 'koma_catalog_source.dart';
import 'recommendation_providers.dart';

/// Day-stable salt so hub cover art doesn't flicker on every rebuild.
int hubCoverSalt() {
  final now = DateTime.now();
  return now.year * 1000 + now.month * 32 + now.day;
}

/// Build shelf entries from lists the Library screen already loaded.
List<LibraryHubEntry> hubShelfFromLibrary({
  required List<Book> books,
  required List<Manga> mangas,
}) {
  return [
    for (final m in mangas)
      if (!ViewerFlags.isHidden(m.viewerFlags))
        LibraryHubEntry(
          title: m.name,
          subtitle: m.author,
          coverPathOrUrl: m.customCoverPath ?? m.imageUrl,
          manga: m,
        ),
    for (final b in books)
      LibraryHubEntry(
        title: b.title,
        subtitle: b.author,
        coverPathOrUrl: b.coverPath,
        book: b,
      ),
  ];
}

/// Soft continue from books with mid-progress (no manga chapter scan needed).
List<LibraryHubEntry> hubContinueFromBooks(List<Book> books) {
  return [
    for (final b in books)
      if (b.progress > 0 && b.progress < 1)
        LibraryHubEntry(
          title: b.title,
          subtitle: '${(b.progress * 100).round()}%',
          coverPathOrUrl: b.coverPath,
          book: b,
        ),
  ];
}

Future<List<RecommendationSeed>> _hubSeeds(Repositories repos) async {
  final seeds = <RecommendationSeed>[];
  final inProgressBooks = await repos.books.getInProgressBooks();
  for (final b in inProgressBooks.take(5)) {
    final meta = await repos.books.getMetadataForBook(b.id);
    final genres = meta?.genres.isNotEmpty == true
        ? List<String>.from(meta!.genres)
        : _splitGenreField(b.genre);
    seeds.add(
      RecommendationSeed(
        title: b.title,
        author: b.author,
        kind: RecommendationContentKind.ebook,
        id: 'book:${b.id}',
        genres: genres,
        signals: ReadingSignals(
          progress: b.progress,
          finished: b.progress >= 0.98,
        ),
      ),
    );
  }
  final inProgressManga = await repos.manga.getInProgressManga();
  for (final row in inProgressManga.take(5)) {
    final m = row.manga;
    seeds.add(
      RecommendationSeed(
        title: m.name,
        author: m.author,
        kind: RecommendationContentKind.manga,
        id: 'manga:${m.id}',
        genres: List<String>.from(m.genres),
        signals: ReadingSignals(
          progress: row.progress,
          finished: m.readingStatus == 2,
        ),
      ),
    );
  }
  if (seeds.isEmpty) {
    final books = await repos.books.getBooks();
    for (final b in books.take(3)) {
      final meta = await repos.books.getMetadataForBook(b.id);
      final genres = meta?.genres.isNotEmpty == true
          ? List<String>.from(meta!.genres)
          : _splitGenreField(b.genre);
      seeds.add(
        RecommendationSeed(
          title: b.title,
          author: b.author,
          kind: RecommendationContentKind.ebook,
          id: 'book:${b.id}',
          genres: genres,
          signals: ReadingSignals(progress: b.progress),
        ),
      );
    }
    final mangas = await repos.manga.getMangasInLibrary();
    for (final m in mangas.take(3)) {
      seeds.add(
        RecommendationSeed(
          title: m.name,
          author: m.author,
          kind: RecommendationContentKind.manga,
          id: 'manga:${m.id}',
          genres: List<String>.from(m.genres),
          signals: ReadingSignals(finished: m.readingStatus == 2),
        ),
      );
    }
  }
  return seeds;
}

List<String> _splitGenreField(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return [
    for (final part in raw.split(RegExp(r'[,/;|]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

LibraryHubEntry _entryFromRec(
  RecommendationItem item, {
  required Map<int, Manga> mangasById,
  required Map<int, Book> booksById,
}) {
  Manga? manga;
  Book? book;
  final id = item.id;
  if (id != null && id.startsWith('manga:')) {
    final mid = int.tryParse(id.substring(6));
    if (mid != null) manga = mangasById[mid];
  } else if (id != null && id.startsWith('book:')) {
    final bid = int.tryParse(id.substring(5));
    if (bid != null) book = booksById[bid];
  }

  final cover = item.coverPathOrUrl?.trim().isNotEmpty == true
      ? item.coverPathOrUrl
      : (manga?.customCoverPath ?? manga?.imageUrl ?? book?.coverPath);

  return LibraryHubEntry(
    title: item.title,
    subtitle: item.reason ?? item.author,
    coverPathOrUrl: cover,
    book: book,
    manga: manga,
    recommendation: item,
  );
}

/// In-progress titles for the Continue face (async chapter scan for manga).
final libraryHubContinueProvider =
    FutureProvider.autoDispose<List<LibraryHubEntry>>((ref) async {
  final repos = ref.watch(repositoriesProvider);
  try {
    final hiddenBooks = await HiddenTitlesPrefs.hiddenBookIds();
    final books = [
      for (final b in await repos.books.getInProgressBooks())
        if (!hiddenBooks.contains(b.id)) b,
    ];
    final mangas = (await repos.manga.getInProgressManga())
        .where(
          (m) =>
              m.manga.inLibrary && !ViewerFlags.isHidden(m.manga.viewerFlags),
        )
        .toList(growable: false);
    final continueEntries = <LibraryHubEntry>[
      for (final b in books)
        LibraryHubEntry(
          title: b.title,
          subtitle: '${(b.progress * 100).round()}%',
          coverPathOrUrl: b.coverPath,
          book: b,
        ),
      for (final row in mangas)
        LibraryHubEntry(
          title: row.manga.name,
          subtitle: '${(row.progress * 100).round()}%',
          coverPathOrUrl: row.manga.customCoverPath ?? row.manga.imageUrl,
          inProgressManga: row,
          manga: row.manga,
        ),
    ];
    continueEntries.sort((a, b) {
      final aAt = a.book?.updatedAt ??
          a.inProgressManga?.lastReadAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.book?.updatedAt ??
          b.inProgressManga?.lastReadAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return continueEntries;
  } catch (e, st) {
    if (kDebugMode) debugPrint('libraryHubContinueProvider failed: $e\n$st');
    return const [];
  }
});

/// Engine-ranked library picks (optional). Empty → UI falls back to shelf.
final libraryHubRankedProvider =
    FutureProvider.autoDispose<List<LibraryHubEntry>>((ref) async {
  final repos = ref.watch(repositoriesProvider);
  final engine = ref.watch(recommendationServiceProvider);
  try {
    final seeds = await _hubSeeds(repos);
    if (seeds.isEmpty) return const [];
    final mangasById = {
      for (final m in await repos.manga.getMangasInLibrary()) m.id: m,
    };
    final booksById = {
      for (final b in await repos.books.getBooks()) b.id: b,
    };
    final libraryResult = await engine
        .recommend(
          RecommendationRequest(
            seeds: seeds,
            limit: 12,
            scope: RecommendationCandidateScope.libraryOnly,
          ),
        )
        .timeout(const Duration(seconds: 4));
    return [
      for (final i in libraryResult.items)
        _entryFromRec(i, mangasById: mangasById, booksById: booksById),
    ];
  } catch (e, st) {
    if (kDebugMode) debugPrint('libraryHubRankedProvider failed: $e\n$st');
    return const [];
  }
});

const _kExploreCache = 'hub_explore_extension_cache_v1';

/// Extension / Discover exploration face.
///
/// Cached on disk so relaunch does not hit sources again. More pages append
/// as the user scrolls View more. Queries prefer the profile genre list
/// ("Your tastes").
class LibraryHubExplore extends AsyncNotifier<LibraryHubFace> {
  int _nextPage = 2;
  bool _busy = false;
  bool _hasMore = true;

  @override
  Future<LibraryHubFace> build() async {
    final tastes = ref.watch(
      userProfileProvider.select((p) => p.preferredGenres.join('\u0001')),
    );
    final genres = tastes.isEmpty ? const <String>[] : tastes.split('\u0001');
    final cached = await _ExploreDisk.load();
    if (cached != null &&
        cached.items.isNotEmpty &&
        _sameGenres(cached.genres, genres)) {
      _nextPage = cached.nextPage;
      _hasMore = true;
      return LibraryHubSnapshot.faceFor(
        LibraryHubKind.exploration,
        cached.items,
        salt: hubCoverSalt(),
      );
    }
    final items = genres.isEmpty
        ? await _fetchQueries(
            (await loadExploreRecentSearches()).take(1).toList(),
            page: 1,
            exclude: const {},
          )
        : await _fetch(genres, page: 1, exclude: const {});
    _nextPage = 2;
    _hasMore = items.isNotEmpty;
    await _ExploreDisk.save(genres, items, nextPage: _nextPage);
    final searches = await loadExploreRecentSearches();
    if (searches.isNotEmpty) {
      // Taste (or the first page) is already visible. Search terms append after.
      unawaited(_appendSearchTerms(items, searches, genres));
    }
    return LibraryHubSnapshot.faceFor(
      LibraryHubKind.exploration,
      items,
      salt: hubCoverSalt(),
    );
  }

  Future<void> _appendSearchTerms(
    List<LibraryHubEntry> base,
    List<String> searches,
    List<String> genres,
  ) async {
    final exclude = {
      for (final e in base)
        if (e.recommendation?.id != null) e.recommendation!.id!,
    };
    final more = await _fetchQueries(
      searches,
      page: 1,
      exclude: exclude,
    );
    if (!ref.mounted || more.isEmpty) return;
    final merged = [...base, ...more];
    _nextPage = 2;
    await _ExploreDisk.save(genres, merged, nextPage: _nextPage);
    state = AsyncData(
      LibraryHubSnapshot.faceFor(
        LibraryHubKind.exploration,
        merged,
        salt: hubCoverSalt(),
      ),
    );
  }

  /// Next catalogue page. No-op while a page is in flight or the feed is exhausted.
  Future<void> loadMore() async {
    if (_busy || !_hasMore) return;
    final current = state.asData?.value;
    if (current == null) return;
    _busy = true;
    try {
      final tastes = ref.read(userProfileProvider).preferredGenres;
      final exclude = {
        for (final e in current.entries)
          if (e.recommendation?.id != null) e.recommendation!.id!,
      };
      final more = await _fetch(
        tastes,
        page: _nextPage,
        exclude: exclude,
      );
      if (more.isEmpty) {
        _hasMore = false;
        return;
      }
      _nextPage += 1;
      final merged = [...current.entries, ...more];
      await _ExploreDisk.save(tastes, merged, nextPage: _nextPage);
      state = AsyncData(
        LibraryHubSnapshot.faceFor(
          LibraryHubKind.exploration,
          merged,
          salt: hubCoverSalt(),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<List<LibraryHubEntry>> _fetch(
    List<String> tastes, {
    required int page,
    required Set<String> exclude,
  }) {
    final hints = [
      for (final g in tastes)
        if (g.trim().isNotEmpty) g.trim(),
    ];
    // First paint uses the top taste only. Extra queries wait for a later page.
    return _fetchQueries(
      hints.isEmpty ? const [] : [hints.first],
      page: page,
      exclude: exclude,
    );
  }

  Future<List<LibraryHubEntry>> _fetchQueries(
    List<String> queries, {
    required int page,
    required Set<String> exclude,
  }) async {
    if (queries.isEmpty) return const [];
    final repos = ref.read(repositoriesProvider);
    try {
      final catalog = KomaCatalogSource(
        repos,
        extensions: ref.read(extensionManagerProvider),
        dispatch: ref.read(extensionServiceProvider),
      );
      final external = await catalog.discoverMangaCandidates(
        genreHints: queries,
        softLimit: 12,
        page: page,
        excludeIds: exclude,
      );
      return [
        for (final c in external)
          LibraryHubEntry(
            title: c.title,
            subtitle: c.sourceLabel.isNotEmpty ? c.sourceLabel : c.author,
            coverPathOrUrl: c.coverPathOrUrl,
            recommendation: RecommendationItem(
              title: c.title,
              author: c.author,
              kind: c.kind,
              score: 0,
              id: c.id,
              coverPathOrUrl: c.coverPathOrUrl,
              sourceLabel: c.sourceLabel,
            ),
          ),
      ];
    } catch (e, st) {
      if (kDebugMode) debugPrint('libraryHubExplore fetch failed: $e\n$st');
      return const [];
    }
  }

  bool _sameGenres(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final libraryHubExploreProvider =
    AsyncNotifierProvider<LibraryHubExplore, LibraryHubFace>(
  LibraryHubExplore.new,
);

class _ExploreDisk {
  static Future<({List<String> genres, int nextPage, List<LibraryHubEntry> items})?>
      load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kExploreCache);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final genres = [
        for (final g in (decoded['genres'] as List?) ?? const []) '$g',
      ];
      final nextPage = (decoded['nextPage'] as num?)?.toInt() ?? 2;
      final items = <LibraryHubEntry>[];
      for (final row in (decoded['items'] as List?) ?? const []) {
        if (row is! Map) continue;
        final title = '${row['title'] ?? ''}'.trim();
        if (title.isEmpty) continue;
        final kindName = '${row['kind'] ?? 'manga'}';
        final kind = kindName == 'ebook'
            ? RecommendationContentKind.ebook
            : RecommendationContentKind.manga;
        final cover = row['cover'] as String?;
        final subtitle = row['subtitle'] as String?;
        items.add(
          LibraryHubEntry(
            title: title,
            subtitle: subtitle,
            coverPathOrUrl: cover,
            recommendation: RecommendationItem(
              title: title,
              author: row['author'] as String?,
              kind: kind,
              score: 0,
              id: row['id'] as String?,
              coverPathOrUrl: cover,
              sourceLabel: row['source'] as String?,
            ),
          ),
        );
      }
      return (genres: genres, nextPage: nextPage, items: items);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    List<String> genres,
    List<LibraryHubEntry> items, {
    required int nextPage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'genres': genres,
      'nextPage': nextPage,
      'items': [
        for (final e in items)
          {
            'title': e.title,
            'subtitle': e.subtitle,
            'cover': e.coverPathOrUrl,
            'id': e.recommendation?.id,
            'author': e.recommendation?.author,
            'source': e.recommendation?.sourceLabel,
            'kind': e.recommendation?.kind.name ?? 'manga',
          },
      ],
    };
    await prefs.setString(_kExploreCache, jsonEncode(payload));
  }
}

const kLibraryHubAnglePref = 'library_hub_angle';

Future<double> loadHubAngle() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(kLibraryHubAnglePref) ?? 0;
}

Future<void> saveHubAngle(double angle) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(kLibraryHubAnglePref, angle);
}
