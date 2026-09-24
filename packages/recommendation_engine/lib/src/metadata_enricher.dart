import 'models.dart';

/// Result of a host-side metadata lookup (Open Library, Google Books, etc.).
///
/// Field names mirror the private engine so host adapters compile against
/// both the public stub and the overridden package.
class MetadataEnrichment {
  final String? title;
  final String? author;
  final RecommendationContentKind? kind;
  final List<String> genres;
  final String? coverUrl;
  final String sourceLabel;

  const MetadataEnrichment({
    this.title,
    this.author,
    this.kind,
    this.genres = const [],
    this.coverUrl,
    this.sourceLabel = 'metadata',
  });

  bool get hasGenres => genres.isNotEmpty;
}

/// Optional host-implemented enricher. The engine never performs HTTP itself.
abstract class MetadataEnricher {
  Future<MetadataEnrichment?> enrich({
    required String title,
    String? author,
    RecommendationContentKind? kindHint,
  });
}
