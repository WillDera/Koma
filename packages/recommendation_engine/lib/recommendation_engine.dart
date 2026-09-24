/// Public stub API surface for host apps.
///
/// Private builds replace this package with the real engine via
/// `pubspec_overrides.yaml` (same package name and exports).
library;

export 'src/catalog.dart';
export 'src/genre_profile.dart';
export 'src/metadata_enricher.dart';
export 'src/models.dart';
export 'src/recommendation_service.dart';
export 'src/scoring.dart';
