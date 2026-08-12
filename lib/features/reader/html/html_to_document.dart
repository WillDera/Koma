import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'reading_document.dart';

/// Converts chapter HTML into a [ReadingDocument].
///
/// Plain text rules mirror [TextExtractor.extractFromHtml] for text-only
/// chapters so existing highlight/TTS offsets stay valid. Images contribute
/// zero characters and are recorded as [ReadingEmbed]s / image blocks.
class HtmlToDocument {
  const HtmlToDocument._();

  static const _blockTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'pre',
    'div',
    'section',
    'article',
    'ul',
    'ol',
    'hr',
  };

  static ReadingDocument parse(String html) {
    if (html.trim().isEmpty) return ReadingDocument.empty;
    final parsed = html_parser.parse(html);
    final body = parsed.body;
    if (body == null) return ReadingDocument.empty;

    final builder = _Builder();
    builder.walkChildren(body, StyleFlags.empty, blockHint: null);
    return builder.finish();
  }
}

class _Builder {
  final StringBuffer _buf = StringBuffer();
  final List<StyleRun> _runs = [];
  final List<ReadingBlock> _blocks = [];
  final List<ReadingEmbed> _embeds = [];

  /// Open block stack: (kind, startOffset, listMarker, listDepth)
  final List<_OpenBlock> _open = [];

  int _olCounter = 0;
  bool _inOl = false;

  void walkChildren(
    dom.Element parent,
    StyleFlags flags, {
    ReadingBlockKind? blockHint,
  }) {
    for (final node in parent.nodes) {
      if (node is dom.Text) {
        _writeText(node.text, flags);
      } else if (node is dom.Element) {
        _walkElement(node, flags, blockHint: blockHint);
      }
    }
  }

  void _walkElement(
    dom.Element el,
    StyleFlags flags, {
    ReadingBlockKind? blockHint,
  }) {
    final tag = el.localName?.toLowerCase() ?? '';
    if (tag == 'script' || tag == 'style' || tag == 'head' || tag == 'meta') {
      return;
    }

    switch (tag) {
      case 'br':
        _buf.write('\n');
        return;
      case 'hr':
        _ensureBlockGap();
        final at = _buf.length;
        _blocks.add(
          ReadingBlock(
            kind: ReadingBlockKind.thematicBreak,
            start: at,
            end: at,
          ),
        );
        _ensureBlockGap();
        return;
      case 'img':
        _addImage(el, isBlock: blockHint != null || _open.isEmpty);
        return;
      case 'em':
      case 'i':
        walkChildren(el, flags.copyWith(italic: true), blockHint: blockHint);
        return;
      case 'strong':
      case 'b':
        walkChildren(el, flags.copyWith(bold: true), blockHint: blockHint);
        return;
      case 'u':
        walkChildren(el, flags.copyWith(underline: true), blockHint: blockHint);
        return;
      case 'code':
      case 'tt':
        walkChildren(el, flags.copyWith(code: true), blockHint: blockHint);
        return;
      case 'a':
        final href = el.attributes['href']?.trim();
        walkChildren(
          el,
          flags.copyWith(
            linkHref: (href != null && href.isNotEmpty) ? href : null,
            underline: true,
          ),
          blockHint: blockHint,
        );
        return;
      case 'h1':
        _withBlock(ReadingBlockKind.heading1, flags, el);
        return;
      case 'h2':
        _withBlock(ReadingBlockKind.heading2, flags, el);
        return;
      case 'h3':
        _withBlock(ReadingBlockKind.heading3, flags, el);
        return;
      case 'h4':
        _withBlock(ReadingBlockKind.heading4, flags, el);
        return;
      case 'h5':
        _withBlock(ReadingBlockKind.heading5, flags, el);
        return;
      case 'h6':
        _withBlock(ReadingBlockKind.heading6, flags, el);
        return;
      case 'blockquote':
        _withBlock(ReadingBlockKind.blockquote, flags, el);
        return;
      case 'p':
      case 'pre':
        _withBlock(ReadingBlockKind.paragraph, flags, el);
        return;
      case 'li':
        _withListItem(flags, el);
        return;
      case 'ul':
        final wasOl = _inOl;
        final prev = _olCounter;
        _inOl = false;
        _ensureBlockGap();
        walkChildren(el, flags);
        _ensureBlockGap();
        _inOl = wasOl;
        _olCounter = prev;
        return;
      case 'ol':
        final wasOl = _inOl;
        final prev = _olCounter;
        _inOl = true;
        _olCounter = 0;
        _ensureBlockGap();
        walkChildren(el, flags);
        _ensureBlockGap();
        _inOl = wasOl;
        _olCounter = prev;
        return;
      default:
        // Unknown / structural: keep walking for text; treat nested block
        // tags normally via recursion.
        if (HtmlToDocument._blockTags.contains(tag) && blockHint == null) {
          // Soft paragraph-ish gap for naked div/section content that has
          // direct text children — still collected without fabricating blocks
          // for every wrapper.
          walkChildren(el, flags, blockHint: blockHint);
        } else {
          walkChildren(el, flags, blockHint: blockHint);
        }
        return;
    }
  }

  void _withBlock(ReadingBlockKind kind, StyleFlags flags, dom.Element el) {
    _ensureBlockGap();
    final start = _buf.length;
    _open.add(_OpenBlock(kind, start));
    walkChildren(el, flags, blockHint: kind);
    _closeBlock();
    _ensureBlockGap();
  }

  void _withListItem(StyleFlags flags, dom.Element el) {
    _ensureBlockGap();
    String marker;
    if (_inOl) {
      _olCounter += 1;
      marker = '$_olCounter.';
    } else {
      marker = '•';
    }
    final start = _buf.length;
    _open.add(
      _OpenBlock(
        ReadingBlockKind.listItem,
        start,
        listMarker: marker,
        listDepth: 1,
      ),
    );
    walkChildren(el, flags, blockHint: ReadingBlockKind.listItem);
    _closeBlock();
    _ensureBlockGap();
  }

  void _closeBlock() {
    if (_open.isEmpty) return;
    final open = _open.removeLast();
    final end = _buf.length;
    // Drop empty text blocks (image-only was handled separately).
    if (end > open.start || open.kind == ReadingBlockKind.thematicBreak) {
      _blocks.add(
        ReadingBlock(
          kind: open.kind,
          start: open.start,
          end: end,
          listMarker: open.listMarker,
          listDepth: open.listDepth,
        ),
      );
    }
  }

  void _addImage(dom.Element el, {required bool isBlock}) {
    final src = (el.attributes['src'] ?? '').trim();
    if (src.isEmpty) return;
    final path = _normalizeImagePath(src);
    if (path == null) return;

    final at = _buf.length;
    if (isBlock) {
      _ensureBlockGap();
    }
    _embeds.add(
      ReadingEmbed(
        path: path,
        afterOffset: at,
        isBlock: isBlock,
        widthHint: double.tryParse(el.attributes['width'] ?? ''),
        heightHint: double.tryParse(el.attributes['height'] ?? ''),
      ),
    );
    if (isBlock) {
      _blocks.add(
        ReadingBlock(
          kind: ReadingBlockKind.image,
          start: at,
          end: at,
          imagePath: path,
        ),
      );
      _ensureBlockGap();
    }
  }

  String? _normalizeImagePath(String src) {
    if (src.startsWith('file://')) {
      return Uri.parse(src).toFilePath();
    }
    if (src.startsWith('/')) return src;
    // Relative / http — leave as-is; import rewrite should have made file paths.
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    return src;
  }

  void _writeText(String raw, StyleFlags flags) {
    if (raw.trim().isEmpty) {
      // Preserve single spaces between inline elements, drop pure whitespace
      // that would only inflate gaps (mirrors TextExtractor skipping empties
      // for all-whitespace nodes — except a lone space between words).
      if (raw.contains(RegExp(r'\S'))) {
        // unreachable for trim-empty
      } else if (raw.contains(' ') &&
          _buf.isNotEmpty &&
          !_endsWithWhitespace()) {
        _appendRun(' ', flags);
      }
      return;
    }
    // Collapse internal runs of spaces/tabs but keep the text itself.
    final cleaned = raw.replaceAll(RegExp(r'[ \t]+'), ' ');
    _appendRun(cleaned, flags);
  }

  void _appendRun(String text, StyleFlags flags) {
    if (text.isEmpty) return;
    final start = _buf.length;
    _buf.write(text);
    final end = _buf.length;
    if (!flags.isDefault) {
      _runs.add(StyleRun(start, end, flags));
    }
  }

  void _ensureBlockGap() {
    if (_buf.isEmpty) return;
    if (!_endsWithNewline()) {
      _buf.write('\n\n');
    }
  }

  bool _endsWithNewline() {
    if (_buf.isEmpty) return false;
    return _buf.toString().endsWith('\n');
  }

  bool _endsWithWhitespace() {
    if (_buf.isEmpty) return true;
    final s = _buf.toString();
    return s.endsWith(' ') || s.endsWith('\n');
  }

  ReadingDocument finish() {
    // If no explicit blocks were opened but we have text (loose body text),
    // wrap it as a single paragraph.
    var plain = _buf
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' \n'), '\n')
        .replaceAll(RegExp(r'\n '), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // After whitespace cleanup lengths may shift; rebuild runs only when plain
    // equals the buffer (common case). When trim shrinks edges, shift runs.
    final before = _buf.toString();
    if (plain != before) {
      final leading = before.length - before.trimLeft().length;
      final clippedRuns = <StyleRun>[];
      for (final r in _runs) {
        final s = (r.start - leading).clamp(0, plain.length);
        final e = (r.end - leading).clamp(0, plain.length);
        if (e > s) clippedRuns.add(StyleRun(s, e, r.flags));
      }
      final clippedBlocks = <ReadingBlock>[];
      for (final b in _blocks) {
        final s = (b.start - leading).clamp(0, plain.length);
        final e = (b.end - leading).clamp(0, plain.length);
        clippedBlocks.add(
          ReadingBlock(
            kind: b.kind,
            start: s,
            end: e,
            imagePath: b.imagePath,
            listMarker: b.listMarker,
            listDepth: b.listDepth,
          ),
        );
      }
      final clippedEmbeds = <ReadingEmbed>[];
      for (final e in _embeds) {
        final at = (e.afterOffset - leading).clamp(0, plain.length);
        clippedEmbeds.add(
          ReadingEmbed(
            path: e.path,
            afterOffset: at,
            isBlock: e.isBlock,
            widthHint: e.widthHint,
            heightHint: e.heightHint,
          ),
        );
      }
      if (clippedBlocks.isEmpty && plain.isNotEmpty) {
        clippedBlocks.add(
          ReadingBlock(
            kind: ReadingBlockKind.paragraph,
            start: 0,
            end: plain.length,
          ),
        );
      }
      return ReadingDocument(
        plainText: plain,
        styleRuns: clippedRuns,
        blocks: clippedBlocks,
        embeds: clippedEmbeds,
      );
    }

    final blocks = List<ReadingBlock>.from(_blocks);
    if (blocks.isEmpty && plain.isNotEmpty) {
      blocks.add(
        ReadingBlock(
          kind: ReadingBlockKind.paragraph,
          start: 0,
          end: plain.length,
        ),
      );
    }
    return ReadingDocument(
      plainText: plain,
      styleRuns: List.unmodifiable(_runs),
      blocks: List.unmodifiable(blocks),
      embeds: List.unmodifiable(_embeds),
    );
  }
}

class _OpenBlock {
  final ReadingBlockKind kind;
  final int start;
  final String? listMarker;
  final int listDepth;

  _OpenBlock(this.kind, this.start, {this.listMarker, this.listDepth = 1});
}
