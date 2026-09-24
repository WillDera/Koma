import 'package:recommendation_engine/recommendation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/rust/api/metadata.dart' as rust;
import '../services/metadata_enrichment_service.dart';

/// Wraps existing Open Library / Google Books lookup for seed enrichment.
///
/// Skips manga-style hints (OL/GB are ebook-oriented).
class KomaMetadataEnricher implements MetadataEnricher {
  @override
  Future<MetadataEnrichment?> enrich({
    required String title,
    String? author,
    RecommendationContentKind? kindHint,
  }) async {
    if (kindHint == RecommendationContentKind.manga) return null;
    final t = title.trim();
    if (t.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final googleKey = prefs.getString(kGoogleBooksApiKeyPref)?.trim();

    final results = await rust.lookupBooks(
      queries: [
        rust.BookLookupQuery(
          id: 0,
          title: t,
          author: author,
        ),
      ],
      googleApiKey:
          (googleKey == null || googleKey.isEmpty) ? null : googleKey,
    );
    if (results.isEmpty || !results.first.found) return null;
    final hit = results.first;
    return MetadataEnrichment(
      title: hit.title,
      author: hit.author,
      genres: List<String>.from(hit.genres),
      kind: RecommendationContentKind.ebook,
      coverUrl: hit.coverUrl,
      sourceLabel: hit.source.isEmpty ? 'metadata' : hit.source,
    );
  }
}
