import 'reading_document.dart';
import 'kir_model.dart';

/// Converts a KIR chapter into a [ReadingDocument].
///
/// Offset rules match [HtmlToDocument] so a chapter painted from KIR uses the
/// same highlight/TTS coordinate space shape (block gaps, images = 0 chars,
/// list markers on the block not in [ReadingDocument.plainText]). Chapter
/// title is **not** prepended — unlike `Chapter::plain_text()` in koma-core.
///
/// [imagePaths] are consumed in document order for `image`/`media` blocks
/// (typically `file://` srcs already rewritten into chapter HTML).
class KirToDocument {
  const KirToDocument._();

  static ReadingDocument parse(
    KirChapter chapter, {
    List<String> imagePaths = const [],
  }) {
    final b = _Builder(imagePaths);
    for (final block in chapter.blocks) {
      b.emit(block, quote: false, listDepth: 1, ordered: false);
    }
    return b.finish();
  }

  /// `file://` / absolute `img` srcs in HTML order, for pairing with KIR images.
  static List<String> imagePathsFromHtml(String html) {
    final out = <String>[];
    final re = RegExp(
      r'''<img\b[^>]*?\bsrc\s*=\s*(["'])([^"']+)\1''',
      caseSensitive: false,
    );
    for (final m in re.allMatches(html)) {
      final src = m.group(2)!.trim();
      if (src.startsWith('file://')) {
        out.add(Uri.parse(src).toFilePath());
      } else if (src.startsWith('/')) {
        out.add(src);
      }
    }
    return out;
  }
}

class _Builder {
  _Builder(this._imagePaths);

  final List<String> _imagePaths;
  int _imageCursor = 0;
  final StringBuffer _buf = StringBuffer();
  final List<StyleRun> _runs = [];
  final List<ReadingBlock> _blocks = [];
  final List<ReadingEmbed> _embeds = [];
  int _olCounter = 0;

  void emit(
    KirBlock block, {
    required bool quote,
    required int listDepth,
    required bool ordered,
  }) {
    switch (block.kind) {
      case 'heading1':
        _textBlock(ReadingBlockKind.heading1, block.spans);
      case 'heading2':
        _textBlock(ReadingBlockKind.heading2, block.spans);
      case 'heading3':
        _textBlock(ReadingBlockKind.heading3, block.spans);
      case 'heading4':
        _textBlock(ReadingBlockKind.heading4, block.spans);
      case 'heading5':
        _textBlock(ReadingBlockKind.heading5, block.spans);
      case 'heading6':
        _textBlock(ReadingBlockKind.heading6, block.spans);
      case 'paragraph':
        _textBlock(
          quote ? ReadingBlockKind.blockquote : ReadingBlockKind.paragraph,
          block.spans,
        );
      case 'image':
      case 'media':
        _image(block);
      case 'quote':
        if (block.children.isEmpty) {
          _textBlock(ReadingBlockKind.blockquote, block.spans);
        } else {
          for (final child in block.children) {
            emit(
              child,
              quote: true,
              listDepth: listDepth,
              ordered: ordered,
            );
          }
        }
      case 'list':
        final was = _olCounter;
        if (block.ordered) _olCounter = 0;
        for (final child in block.children) {
          _listItem(
            child,
            depth: listDepth,
            ordered: block.ordered,
          );
        }
        _olCounter = was;
      default:
        if (block.spans.isNotEmpty) {
          _textBlock(ReadingBlockKind.paragraph, block.spans);
        } else {
          for (final child in block.children) {
            emit(
              child,
              quote: quote,
              listDepth: listDepth,
              ordered: ordered,
            );
          }
        }
    }
  }

  void _listItem(KirBlock child, {required int depth, required bool ordered}) {
    if (child.kind == 'list') {
      emit(child, quote: false, listDepth: depth + 1, ordered: child.ordered);
      return;
    }
    _ensureBlockGap();
    String marker;
    if (ordered) {
      _olCounter += 1;
      marker = '$_olCounter.';
    } else {
      marker = '•';
    }
    final start = _buf.length;
    if (child.kind == 'image' || child.kind == 'media') {
      _image(child);
    } else if (child.children.isNotEmpty && child.spans.isEmpty) {
      for (final nested in child.children) {
        _writeSpans(nested.spans);
      }
    } else {
      _writeSpans(child.spans);
    }
    final end = _buf.length;
    _blocks.add(
      ReadingBlock(
        kind: ReadingBlockKind.listItem,
        start: start,
        end: end,
        listMarker: marker,
        listDepth: depth,
      ),
    );
    _ensureBlockGap();
  }

  void _textBlock(ReadingBlockKind kind, List<KirSpan> spans) {
    _ensureBlockGap();
    final start = _buf.length;
    _writeSpans(spans);
    final end = _buf.length;
    if (end > start) {
      _blocks.add(ReadingBlock(kind: kind, start: start, end: end));
    }
    _ensureBlockGap();
  }

  void _image(KirBlock block) {
    String? path;
    if (_imageCursor < _imagePaths.length) {
      path = _imagePaths[_imageCursor++];
    }
    final at = _buf.length;
    _ensureBlockGap();
    if (path != null && path.isNotEmpty) {
      _embeds.add(
        ReadingEmbed(path: path, afterOffset: at, isBlock: true),
      );
      _blocks.add(
        ReadingBlock(
          kind: ReadingBlockKind.image,
          start: at,
          end: at,
          imagePath: path,
        ),
      );
    }
    _ensureBlockGap();
  }

  void _writeSpans(List<KirSpan> spans) {
    for (final s in spans) {
      if (s.text.isEmpty) continue;
      final flags = StyleFlags(
        bold: s.bold,
        italic: s.italic,
        underline: s.underline,
        colorHex: s.color,
      );
      final start = _buf.length;
      _buf.write(s.text);
      final end = _buf.length;
      if (!flags.isDefault) {
        _runs.add(StyleRun(start, end, flags));
      }
    }
  }

  void _ensureBlockGap() {
    if (_buf.isEmpty) return;
    if (!_buf.toString().endsWith('\n')) {
      _buf.write('\n\n');
    }
  }

  ReadingDocument finish() {
    var plain = _buf
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' \n'), '\n')
        .replaceAll(RegExp(r'\n '), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final before = _buf.toString();
    var runs = _runs;
    var blocks = _blocks;
    var embeds = _embeds;
    if (plain != before) {
      final leading = before.length - before.trimLeft().length;
      runs = [
        for (final r in _runs)
          if (r.clipped(leading, leading + plain.length) != null)
            StyleRun(
              (r.start - leading).clamp(0, plain.length),
              (r.end - leading).clamp(0, plain.length),
              r.flags,
            ),
      ];
      blocks = [
        for (final b in _blocks)
          ReadingBlock(
            kind: b.kind,
            start: (b.start - leading).clamp(0, plain.length),
            end: (b.end - leading).clamp(0, plain.length),
            imagePath: b.imagePath,
            listMarker: b.listMarker,
            listDepth: b.listDepth,
          ),
      ];
      embeds = [
        for (final e in _embeds)
          ReadingEmbed(
            path: e.path,
            afterOffset: (e.afterOffset - leading).clamp(0, plain.length),
            isBlock: e.isBlock,
            widthHint: e.widthHint,
            heightHint: e.heightHint,
          ),
      ];
    }
    return ReadingDocument(
      plainText: plain,
      styleRuns: runs,
      blocks: blocks,
      embeds: embeds,
    );
  }
}
