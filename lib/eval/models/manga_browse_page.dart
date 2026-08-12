import 'm_manga.dart';

/// Result of a catalogue browse/search page from an extension.
///
/// Distinct from [MPages], which holds chapter page images for the reader.
class MangaBrowsePage {
  final List<MManga> list;
  final bool hasNextPage;

  const MangaBrowsePage({required this.list, this.hasNextPage = false});
}
