import 'package:recommendation_engine/recommendation_engine.dart';

import '../../eval/dispatch_service.dart';
import '../../eval/models/m_source.dart';
import '../models/book.dart';
import '../models/extension_source.dart';
import '../models/manga.dart';
import '../repositories/repositories.dart';
import '../services/extension_manager.dart';

/// Maps Koma library + optional Discover / extension hits into [CatalogItem]s.
class KomaCatalogSource implements CatalogSource {
  KomaCatalogSource(
    this._repos, {
    this.extensions,
    this.dispatch,
    this.maxDiscoverSources = 4,
    this.perSourceHitCap = 6,
    this.discoverSearchTimeout = const Duration(seconds: 8),
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
    List<String> genreHints = const [],
    int softLimit = 80,
  }) async {
    final out = <CatalogItem>[];
    final wantEbook =
        kinds == null || kinds.contains(RecommendationContentKind.ebook);
    final wantManga =
        kinds == null || kinds.contains(RecommendationContentKind.manga);

    final libraryTitles = <String>{};

    if (wantEbook) {
      final books = await _repos.books.getBooks();
      for (final b in books) {
        out.add(_fromBook(b, await _bookGenres(b)));
        libraryTitles.add(_norm(b.title));
      }
    }
    if (wantManga) {
      final mangas = await _repos.manga.getMangasInLibrary();
      for (final m in mangas) {
        out.add(_fromManga(m));
        libraryTitles.add(_norm(m.name));
      }
    }

    if (wantManga &&
        scopeWantsExternal(scope) &&
        genreHints.isNotEmpty &&
        extensions != null &&
        dispatch != null) {
      final external = await _discoverMangaCandidates(
        genreHints: genreHints,
        libraryTitles: libraryTitles,
        remaining: (softLimit - out.length).clamp(0, softLimit),
      );
      out.addAll(external);
    }

    if (out.length > softLimit) {
      return out.sublist(0, softLimit);
    }
    return out;
  }

  Future<List<CatalogItem>> _discoverMangaCandidates({
    required List<String> genreHints,
    required Set<String> libraryTitles,
    required int remaining,
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
    // Prefer the strongest consensus genres as search queries.
    final queries = genreHints.take(2).toList();
    if (queries.isEmpty) return const [];

    final out = <CatalogItem>[];
    final seen = <String>{};

    for (final query in queries) {
      if (out.length >= remaining) break;
      final futures = <Future<List<CatalogItem>>>[
        for (final src in picked)
          _searchOneSource(
            dispatch: dispatch,
            source: src,
            query: query,
            genreHints: genreHints,
            libraryTitles: libraryTitles,
          ),
      ];
      final batches = await Future.wait(futures);
      for (final batch in batches) {
        for (final item in batch) {
          final key = '${item.sourceId}|${_norm(item.title)}';
          if (!seen.add(key)) continue;
          if (libraryTitles.contains(_norm(item.title))) continue;
          out.add(item);
          if (out.length >= remaining) {
            return out;
          }
        }
      }
    }
    return out;
  }

  Future<List<CatalogItem>> _searchOneSource({
    required ExtensionDispatchService dispatch,
    required ExtensionSource source,
    required String query,
    required List<String> genreHints,
    required Set<String> libraryTitles,
  }) async {
    try {
      final page = await dispatch
          .search(MSource.fromExtensionSource(source), 1, query)
          .timeout(discoverSearchTimeout);
      final hits = <CatalogItem>[];
      for (final manga in page.list.take(perSourceHitCap)) {
        final title = manga.title.trim();
        if (title.isEmpty) continue;
        if (libraryTitles.contains(_norm(title))) continue;
        final url = manga.url.trim();
        if (url.isEmpty) continue;
        hits.add(
          CatalogItem(
            id: extensionCatalogId(source.sourceId, url),
            title: title,
            author: manga.author,
            kind: RecommendationContentKind.manga,
            genres: normalizeGenres([
              ...genreHints,
              ...manga.genres,
            ]),
            coverPathOrUrl: manga.thumbnailUrl,
            sourceLabel: source.name,
            inLibrary: false,
            sourceId: source.sourceId,
            sourceUrl: url,
          ),
        );
      }
      return hits;
    } catch (_) {
      // Best-effort Discover; one source failure must not fail recommend().
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
        inLibrary: true,
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
        inLibrary: true,
        sourceId: manga.sourceId,
        sourceUrl: manga.url,
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
