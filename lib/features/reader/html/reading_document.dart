import 'package:flutter/foundation.dart';

/// Semantic block kinds produced by the Phase‑1 HTML allowlist.
enum ReadingBlockKind {
  paragraph,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  blockquote,
  listItem,
  image,
  thematicBreak,
}

/// Inline style flags for a character run into [ReadingDocument.plainText].
@immutable
class StyleFlags {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool code;
  final String? linkHref;
  final String? colorHex;

  const StyleFlags({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.code = false,
    this.linkHref,
    this.colorHex,
  });

  static const empty = StyleFlags();

  bool get isDefault =>
      !bold &&
      !italic &&
      !underline &&
      !code &&
      linkHref == null &&
      colorHex == null;

  StyleFlags copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? code,
    Object? linkHref = _unset,
    Object? colorHex = _unset,
  }) {
    return StyleFlags(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      code: code ?? this.code,
      linkHref: identical(linkHref, _unset)
          ? this.linkHref
          : linkHref as String?,
      colorHex: identical(colorHex, _unset)
          ? this.colorHex
          : colorHex as String?,
    );
  }

  StyleFlags merge(StyleFlags other) {
    return StyleFlags(
      bold: bold || other.bold,
      italic: italic || other.italic,
      underline: underline || other.underline,
      code: code || other.code,
      linkHref: other.linkHref ?? linkHref,
      colorHex: other.colorHex ?? colorHex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StyleFlags &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.code == code &&
      other.linkHref == linkHref &&
      other.colorHex == colorHex;

  @override
  int get hashCode =>
      Object.hash(bold, italic, underline, code, linkHref, colorHex);
}

const Object _unset = Object();

/// Half-open `[start, end)` run of [StyleFlags] into [ReadingDocument.plainText].
@immutable
class StyleRun {
  final int start;
  final int end;
  final StyleFlags flags;

  const StyleRun(this.start, this.end, this.flags);

  int get length => end - start;

  bool overlaps(int rangeStart, int rangeEnd) =>
      start < rangeEnd && end > rangeStart;

  StyleRun? clipped(int rangeStart, int rangeEnd) {
    final s = start < rangeStart ? rangeStart : start;
    final e = end > rangeEnd ? rangeEnd : end;
    if (e <= s) return null;
    return StyleRun(s, e, flags);
  }

  @override
  bool operator ==(Object other) =>
      other is StyleRun &&
      other.start == start &&
      other.end == end &&
      other.flags == flags;

  @override
  int get hashCode => Object.hash(start, end, flags);
}

/// Ordered block in the chapter flow.
@immutable
class ReadingBlock {
  final ReadingBlockKind kind;

  /// Character range into [ReadingDocument.plainText]. Empty for pure media.
  final int start;
  final int end;

  /// Local file path for [ReadingBlockKind.image]; null otherwise.
  final String? imagePath;

  /// Optional list marker (`•` / `1.`) for [ReadingBlockKind.listItem].
  final String? listMarker;

  /// 1-based depth for nested lists (Phase 1 usually 1).
  final int listDepth;

  const ReadingBlock({
    required this.kind,
    required this.start,
    required this.end,
    this.imagePath,
    this.listMarker,
    this.listDepth = 1,
  });

  bool get hasText => end > start;

  bool get isHeading =>
      kind == ReadingBlockKind.heading1 ||
      kind == ReadingBlockKind.heading2 ||
      kind == ReadingBlockKind.heading3 ||
      kind == ReadingBlockKind.heading4 ||
      kind == ReadingBlockKind.heading5 ||
      kind == ReadingBlockKind.heading6;

  double headingScale() {
    return switch (kind) {
      ReadingBlockKind.heading1 => 1.5,
      ReadingBlockKind.heading2 => 1.3,
      ReadingBlockKind.heading3 => 1.15,
      ReadingBlockKind.heading4 => 1.08,
      ReadingBlockKind.heading5 => 1.04,
      ReadingBlockKind.heading6 => 1.0,
      _ => 1.0,
    };
  }
}

/// Image embed anchored next to plain-text coordinates (images contribute 0
/// characters so highlight/TTS offsets stay stable).
@immutable
class ReadingEmbed {
  final String path;

  /// Character offset in [ReadingDocument.plainText] after which this image
  /// should appear (0 = before first character).
  final int afterOffset;

  final bool isBlock;
  final double? widthHint;
  final double? heightHint;

  const ReadingEmbed({
    required this.path,
    required this.afterOffset,
    this.isBlock = true,
    this.widthHint,
    this.heightHint,
  });
}

/// Structured reading content derived from chapter HTML.
///
/// [plainText] is the highlight / TTS / resume coordinate space — the same
/// role historically filled by [TextExtractor.extractFromHtml].
@immutable
class ReadingDocument {
  final String plainText;
  final List<StyleRun> styleRuns;
  final List<ReadingBlock> blocks;
  final List<ReadingEmbed> embeds;

  const ReadingDocument({
    required this.plainText,
    this.styleRuns = const [],
    this.blocks = const [],
    this.embeds = const [],
  });

  static const empty = ReadingDocument(plainText: '');

  bool get isEmpty => plainText.isEmpty && embeds.isEmpty;

  /// Style runs intersecting `[rangeStart, rangeEnd)`, clipped to that range.
  List<StyleRun> styleRunsInRange(int rangeStart, int rangeEnd) {
    final out = <StyleRun>[];
    for (final run in styleRuns) {
      final clipped = run.clipped(rangeStart, rangeEnd);
      if (clipped != null) out.add(clipped);
    }
    return out;
  }

  /// Embeds whose [ReadingEmbed.afterOffset] falls in `[rangeStart, rangeEnd)`.
  List<ReadingEmbed> embedsInRange(int rangeStart, int rangeEnd) {
    return embeds
        .where((e) => e.afterOffset >= rangeStart && e.afterOffset < rangeEnd)
        .toList(growable: false);
  }

  /// Blocks that intersect the character range (or image blocks whose
  /// [ReadingBlock.start] falls inside — images have start==end==anchor).
  List<ReadingBlock> blocksInRange(int rangeStart, int rangeEnd) {
    return blocks.where((b) {
      if (b.kind == ReadingBlockKind.image ||
          b.kind == ReadingBlockKind.thematicBreak) {
        return b.start >= rangeStart && b.start < rangeEnd;
      }
      return b.start < rangeEnd && b.end > rangeStart;
    }).toList(growable: false);
  }
}
