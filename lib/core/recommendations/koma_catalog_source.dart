import 'dart:async';

import 'package:recommendation_engine/recommendation_engine.dart';

import '../../eval/dispatch_service.dart';
import '../../eval/models/m_source.dart';
import '../models/book.dart';
import '../models/extension_source.dart';
import '../models/manga.dart';
import '../repositories/repositories.dart';
import '../services/extension_manager.dart';

/// Maps Koma library (+ optional Discover search) into [CatalogItem]s.
///
/// Matches [recommendation_engine] 0.2.x ([just-nibble/recommendation-engine](
/// https://github.com/just-nibble/recommendation-engine)). Discover hits use
/// `ext:…` ids; library rows use `book:` / `manga:`.
class KomaCatalogSource implements CatalogSource {
  KomaCatalogSource(
    this._repos, {
    this.extensions,
    this.dispatch,
    this.maxDiscoverSources = 3,
    this.perSourceHitCap = 6,
    this.discoverSearchTimeout = const Duration(seconds: 3),
  });

  final Repositories _repos;
  final ExtensionManager? extensions;
  final ExtensionDispatchService? dispatch;
  final int maxDiscoverSources;
  final int perSourceHitCap;
  final Duration discoverSearchTimeout;

  @override
  Future<CatalogItem?> findById(String id) async {
    if (id.startsWith('book:')) {
      final bookId = int.tryParse(id.substring(5));
      if (bookId == null) return null;
      final book = await _repos.books.getBook(bookId);
      if (book == null) return null;
      return _fromBook(book, await _bookGenres(book));
    }
    if (id.startsWith('manga:')) {
      final mangaId = int.tryParse(id.substring(6));
      if (mangaId == null) return null;
      final manga = await _repos.manga.getMangaById(mangaId);
      if (manga == null) return null;
      return _fromManga(manga);
    }
    return null;
  }

  @override
  Future<CatalogItem?> findByTitle({
    required String title,
    String? author,
    RecommendationContentKind? kindHint,
  }) async {
    final key = _norm(title);
    if (key.isEmpty) return null;

    if (kindHint == null || kindHint == RecommendationContentKind.ebook) {
      final books = await _repos.books.getBooks();
      final match = _matchBook(books, key, author);
      if (match != null) {
        return _fromBook(match, await _bookGenres(match));
      }
      if (kindHint == RecommendationContentKind.ebook) return null;
    }

    if (kindHint == null || kindHint == RecommendationContentKind.manga) {
      final byName = await _repos.manga.findMangaByNameIgnoreCase(title);
      if (byName != null && byName.inLibrary) {
        if (author == null ||
            author.trim().isEmpty ||
            _norm(byName.author ?? '') == _norm(author)) {
          return _fromManga(byName);
        }
      }
      final mangas = await _repos.manga.getMangasInLibrary();
      for (final m in mangas) {
        if (_norm(m.name) != key) continue;
        if (author != null &&
            author.trim().isNotEmpty &&
            _norm(m.author ?? '') != _norm(author)) {
          continue;
        }
        return _fromManga(m);
      }
    }
    return null;
  }

  @override
  Future<List<CatalogItem>> listCandidates({
    Set<RecommendationContentKind>? kinds,
    RecommendationCandidateScope scope =
        RecommendationCandidateScope.libraryOnly,
  }) async {
    final out = <CatalogItem>[];
    final wantEbook =
        kinds == null || kinds.contains(RecommendationContentKind.ebook);
    final wantManga =
        kinds == null || kinds.contains(RecommendationContentKind.manga);

    if (wantEbook) {
      final books = await _repos.books.getBooks();
      for (final b in books) {
        out.add(_fromBook(b, await _bookGenres(b)));
      }
    }
    if (wantManga) {
      final mangas = await _repos.manga.getMangasInLibrary();
      for (final m in mangas) {
        out.add(_fromManga(m));
      }
    }

    // Public engine 0.2 does not pass genreHints. Keep library (+ metadata
    // scope still returns library here); Explore uses [discoverMangaCandidates].
    return out;
  }

  /// Host-owned Discover search (extension catalogue). Used by the hub Explore
  /// face because the public engine does not yet pass genre hints into
  /// [listCandidates].
  Future<List<CatalogItem>> discoverMangaCandidates({
    required List<String> genreHints,
    int softLimit = 24,
    int page = 1,
    Set<String> excludeIds = const {},
  }) async {
    if (genreHints.isEmpty ||
        extensions == null ||
        dispatch == null ||
        softLimit <= 0) {
      return const [];
    }
    final libraryTitles = <String>{
      for (final m in await _repos.manga.getMangasInLibrary()) _norm(m.name),
      for (final b in await _repos.books.getBooks()) _norm(b.title),
    };
    return _discoverMangaCandidates(
      genreHints: genreHints,
      libraryTitles: libraryTitles,
      remaining: softLimit,
      page: page < 1 ? 1 : page,
      excludeIds: excludeIds,
    );
  }

  Future<List<CatalogItem>> _discoverMangaCandidates({
    required List<String> genreHints,
    required Set<String> libraryTitles,
    required int remaining,
    required int page,
    required Set<String> excludeIds,
  }) async {
    if (remaining <= 0) return const [];
    final extensions = this.extensions!;
    final dispatch = this.dispatch!;

    final installed = await extensions.listInstalled();
    final sources = installed
        .where((s) => s.isInstalled && s.isActive)
        .where((s) {
          final t = s.itemType.toLowerCase();
          return t.isEmpty || t == 'manga' || t == 'comic' || t == 'manhwa';
        })
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (sources.isEmpty) return const [];

    final picked = sources.take(maxDiscoverSources).toList();
    // One query so the first results don't wait on a second round of sources.
    final query = genreHints
        .map((g) => g.trim())
        .firstWhere((g) => g.isNotEmpty, orElse: () => '');
    if (query.isEmpty) return const [];

    final futures = [
      for (final src in picked)
        _searchOneSource(
          dispatch: dispatch,
          source: src,
          query: query,
          genreHints: genreHints,
          libraryTitles: libraryTitles,
          page: page,
          excludeIds: excludeIds,
        ),
    ];
    return _firstReady(
      futures,
      libraryTitles: libraryTitles,
      excludeIds: excludeIds,
      limit: remaining,
    );
  }

  /// Returns as soon as enough hits are in, without waiting out the slowest source.
  Future<List<CatalogItem>> _firstReady(
    List<Future<List<CatalogItem>>> futures, {
    required Set<String> libraryTitles,
    required Set<String> excludeIds,
    required int limit,
  }) async {
    if (futures.isEmpty || limit <= 0) return const [];
    final out = <CatalogItem>[];
    final seen = <String>{};
    final done = Completer<List<CatalogItem>>();
    var finished = 0;

    void consider(List<CatalogItem> batch) {
      for (final item in batch) {
        if (out.length >= limit) break;
        if (excludeIds.contains(item.id)) continue;
        final key = '${item.sourceLabel}|${_norm(item.title)}';
        if (!seen.add(key)) continue;
        if (libraryTitles.contains(_norm(item.title))) continue;
        out.add(item);
      }
      if (!done.isCompleted &&
          (out.length >= limit || finished >= futures.length)) {
        done.complete(List<CatalogItem>.from(out));
      }
    }

    for (final future in futures) {
      future.then(
        (batch) {
          finished++;
          consider(batch);
        },
        onError: (Object _) {
          finished++;
          consider(const []);
        },
      );
    }

    return done.future.timeout(
      discoverSearchTimeout + const Duration(milliseconds: 400),
      onTimeout: () => List<CatalogItem>.from(out),
    );
  }

  Future<List<CatalogItem>> _searchOneSource({
    required ExtensionDispatchService dispatch,
    required ExtensionSource source,
    required String query,
    required List<String> genreHints,
    required Set<String> libraryTitles,
    required int page,
    required Set<String> excludeIds,
  }) async {
    try {
      final pageResult = await dispatch
          .search(MSource.fromExtensionSource(source), page, query)
          .timeout(discoverSearchTimeout);
      final hits = <CatalogItem>[];
      for (final manga in pageResult.list.take(perSourceHitCap)) {
        final title = manga.title.trim();
        if (title.isEmpty) continue;
        if (libraryTitles.contains(_norm(title))) continue;
        final url = manga.url.trim();
        if (url.isEmpty) continue;
        final id = extensionCatalogId(source.sourceId, url);
        if (excludeIds.contains(id)) continue;
        hits.add(
          CatalogItem(
            id: id,
            title: title,
            author: manga.author,
            kind: RecommendationContentKind.manga,
            genres: normalizeGenres([
              ...genreHints,
              ...manga.genres,
            ]),
            coverPathOrUrl: manga.thumbnailUrl,
            sourceLabel: source.name,
          ),
        );
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  Book? _matchBook(List<Book> books, String key, String? author) {
    final authorKey =
        author == null || author.trim().isEmpty ? null : _norm(author);
    Book? titleOnly;
    for (final b in books) {
      if (_norm(b.title) != key) continue;
      if (authorKey == null) return b;
      if (_norm(b.author ?? '') == authorKey) return b;
      titleOnly ??= b;
    }
    return titleOnly;
  }

  Future<List<String>> _bookGenres(Book book) async {
    final meta = await _repos.books.getMetadataForBook(book.id);
    if (meta != null && meta.genres.isNotEmpty) {
      return List<String>.from(meta.genres);
    }
    return _splitGenres(book.genre);
  }

  CatalogItem _fromBook(Book book, List<String> genres) => CatalogItem(
        id: 'book:${book.id}',
        title: book.title,
        author: book.author,
        kind: RecommendationContentKind.ebook,
        genres: genres,
        progress: book.progress,
        finished: book.progress >= 0.98,
        coverPathOrUrl: book.coverPath,
        sourceLabel: 'library',
      );

  CatalogItem _fromManga(Manga manga) => CatalogItem(
        id: 'manga:${manga.id}',
        title: manga.name,
        author: manga.author,
        kind: RecommendationContentKind.manga,
        genres: List<String>.from(manga.genres),
        readingStatus: manga.readingStatus,
        finished: manga.readingStatus == 2,
        coverPathOrUrl: manga.customCoverPath ?? manga.imageUrl,
        sourceLabel: 'library',
      );

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<String> _splitGenres(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[,;/|]'))
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList(growable: false);
  }
}

/// Opaque id for an extension catalogue hit.
String extensionCatalogId(String sourceId, String url) =>
    'ext:${Uri.encodeComponent(sourceId)}:${Uri.encodeComponent(url)}';

/// Parse [extensionCatalogId] back into sourceId + url.
({String sourceId, String url})? parseExtensionCatalogId(String id) {
  if (!id.startsWith('ext:')) return null;
  final rest = id.substring(4);
  final idx = rest.indexOf(':');
  if (idx <= 0 || idx >= rest.length - 1) return null;
  return (
    sourceId: Uri.decodeComponent(rest.substring(0, idx)),
    url: Uri.decodeComponent(rest.substring(idx + 1)),
  );
}

/// Library rows use `book:` / `manga:` ids; Discover uses `ext:`.
bool recommendationIdIsLibrary(String? id) {
  if (id == null || id.isEmpty) return true;
  return id.startsWith('book:') || id.startsWith('manga:');
}

bool recommendationIdIsDiscover(String? id) =>
    id != null && id.startsWith('ext:');
