import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recommendation_engine/recommendation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../models/manga.dart';
import '../providers.dart';
import '../repositories/repositories.dart';
import '../services/hidden_titles_prefs.dart';
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

/// Extension / Discover exploration face (may take longer; soft-fail).
final libraryHubExploreProvider =
    FutureProvider.autoDispose<LibraryHubFace>((ref) async {
  final repos = ref.watch(repositoriesProvider);
  final engine = ref.watch(recommendationServiceProvider);
  final salt = hubCoverSalt();
  try {
    final seeds = await _hubSeeds(repos);
    if (seeds.isEmpty) {
      return LibraryHubSnapshot.faceFor(
        LibraryHubKind.exploration,
        const [],
        salt: salt,
      );
    }
    final mangasById = {
      for (final m in await repos.manga.getMangasInLibrary()) m.id: m,
    };
    final booksById = {
      for (final b in await repos.books.getBooks()) b.id: b,
    };

    LibraryHubEntry entryOf(RecommendationItem i) => _entryFromRec(
          i,
          mangasById: mangasById,
          booksById: booksById,
        );

    final exploreResult = await engine
        .recommend(
          RecommendationRequest(
            seeds: seeds,
            limit: 12,
            scope: RecommendationCandidateScope.libraryAndMetadata,
          ),
        )
        .timeout(const Duration(seconds: 16));

    var items = [
      for (final i in exploreResult.items)
        if (recommendationIdIsDiscover(i.id)) entryOf(i),
    ];

    // Host Discover pass — public engine 0.2 does not pass genreHints.
    if (items.isEmpty) {
      final hints = <String>{
        for (final s in seeds)
          for (final g in s.genres)
            if (g.trim().isNotEmpty) g.trim(),
      };
      if (hints.isEmpty) {
        for (final s in seeds) {
          final parts = s.title.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty && parts.first.length >= 3) {
            hints.add(parts.first);
          }
        }
      }
      if (hints.isNotEmpty) {
        final catalog = KomaCatalogSource(
          repos,
          extensions: ref.read(extensionManagerProvider),
          dispatch: ref.read(extensionServiceProvider),
        );
        final external = await catalog.discoverMangaCandidates(
          genreHints: hints.take(5).toList(growable: false),
          softLimit: 40,
        );
        items = [
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
      }
    }

    if (kDebugMode) {
      debugPrint(
        'libraryHubExplore: ${items.length} items '
        'diag=${exploreResult.diagnostics.join(",")}',
      );
    }

    return LibraryHubSnapshot.faceFor(
      LibraryHubKind.exploration,
      items,
      salt: salt,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('libraryHubExploreProvider failed: $e\n$st');
    }
    return LibraryHubSnapshot.faceFor(
      LibraryHubKind.exploration,
      const [],
      salt: salt,
    );
  }
});

const kLibraryHubAnglePref = 'library_hub_angle';

Future<double> loadHubAngle() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(kLibraryHubAnglePref) ?? 0;
}

Future<void> saveHubAngle(double angle) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(kLibraryHubAnglePref, angle);
}
