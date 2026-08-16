/// KIR-shaped chapter used by [KirToDocument].
///
/// Mirrors the FRB DTOs in `lib/src/rust/api/koma.dart` so tests do not need
/// the native engine. Import-time decode maps FRB → these types.
class KirSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? color;

  const KirSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
  });
}

class KirBlock {
  /// `paragraph`, `heading1`…`heading6`, `image`, `media`, `quote`, `list`.
  final String kind;
  final List<KirSpan> spans;
  final String? mediaId;
  final String? alt;
  final bool ordered;
  final List<KirBlock> children;

  const KirBlock({
    required this.kind,
    this.spans = const [],
    this.mediaId,
    this.alt,
    this.ordered = false,
    this.children = const [],
  });
}

class KirChapter {
  final String id;
  final String? title;
  final List<KirBlock> blocks;

  const KirChapter({
    required this.id,
    this.title,
    this.blocks = const [],
  });
}
