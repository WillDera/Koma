import 'catalog.dart';
import 'metadata_enricher.dart';
import 'models.dart';

/// Stub engine: always returns an empty result.
class RecommendationService {
  final CatalogSource catalog;
  final MetadataEnricher? enricher;
  final bool enableEnrichment;
  final double alreadyOwnedPenalty;
  final double externalBonus;

  RecommendationService(
    this.catalog, {
    this.enricher,
    this.enableEnrichment = true,
    this.alreadyOwnedPenalty = 0.35,
    this.externalBonus = 0.25,
  });

  Future<RecommendationResult> recommend(RecommendationRequest request) async {
    return RecommendationResult(
      diagnostics: [
        'stub',
        request.wantsExternalCandidates ? 'scope:discover' : 'scope:library',
      ],
    );
  }
}
