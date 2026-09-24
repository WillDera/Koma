import 'models.dart';

class CatalogItem {
  final String id;
  final String title;
  final String? author;
  final RecommendationContentKind kind;
  final List<String> genres;
  final double? progress;
  final bool? finished;
  final int? readingStatus;
  final String? coverPathOrUrl;
  final String sourceLabel;
  final bool inLibrary;
  final String? sourceId;
  final String? sourceUrl;

  const CatalogItem({
    required this.id,
    required this.title,
    this.author,
    required this.kind,
    this.genres = const [],
    this.progress,
    this.finished,
    this.readingStatus,
    this.coverPathOrUrl,
    this.sourceLabel = 'library',
    this.inLibrary = true,
    this.sourceId,
    this.sourceUrl,
  });
}

abstract class CatalogSource {
  Future<CatalogItem?> findById(String id);

  Future<CatalogItem?> findByTitle({
    required String title,
    String? author,
    RecommendationContentKind? kindHint,
  });

  Future<List<CatalogItem>> listCandidates({
    Set<RecommendationContentKind>? kinds,
    RecommendationCandidateScope scope =
        RecommendationCandidateScope.libraryOnly,
    List<String> genreHints = const [],
    int softLimit = 80,
  });
}

class InMemoryCatalogSource implements CatalogSource {
  final List<CatalogItem> items;

  InMemoryCatalogSource(this.items);

  @override
  Future<CatalogItem?> findById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<CatalogItem?> findByTitle({
    required String title,
    String? author,
    RecommendationContentKind? kindHint,
  }) async {
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
    return const [];
  }
}

bool scopeWantsExternal(RecommendationCandidateScope scope) =>
    scope == RecommendationCandidateScope.libraryAndDiscover ||
    scope == RecommendationCandidateScope.libraryAndMetadata;
