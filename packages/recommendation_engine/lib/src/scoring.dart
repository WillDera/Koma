import 'models.dart';

class ScoredCandidate {
  final String title;
  final String? author;
  final RecommendationContentKind kind;
  final List<String> genres;
  final String? id;
  final String? coverPathOrUrl;
  final String sourceLabel;
  final String? sourceId;
  final String? sourceUrl;
  final bool inLibrary;
  final double score;
  final List<String> matchedGenres;

  const ScoredCandidate({
    required this.title,
    this.author,
    required this.kind,
    required this.genres,
    this.id,
    this.coverPathOrUrl,
    this.sourceLabel = 'library',
    this.sourceId,
    this.sourceUrl,
    this.inLibrary = true,
    required this.score,
    required this.matchedGenres,
  });
}

List<ScoredCandidate> collapseDuplicateTitles(List<ScoredCandidate> scored) =>
    scored;
