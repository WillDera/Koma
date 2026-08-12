import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/highlight.dart';
import 'package:koma/core/utils/text_extractor.dart';
import 'package:koma/features/reader/pagination/reading_spans.dart';
import 'package:koma/theme/theme_state.dart';

void main() {
  // ThemeState.accentColor reads WidgetsBinding.instance to resolve the
  // system brightness, so the binding must exist before any TTS-tinted span.
  TestWidgetsFlutterBinding.ensureInitialized();

  const base = TextStyle(fontSize: 16);
  const prov = ThemeState();

  Highlight hl(int start, int end, {String color = 'yellow'}) => Highlight(
    id: start,
    bookId: 1,
    chapterId: 1,
    startOffset: start,
    endOffset: end,
    color: color,
    text: '',
  );

  List<TextSpan> build(
    String text, {
    ThemeState p = prov,
    List<Highlight> highlights = const [],
    bool ttsActive = false,
    int ttsStart = 0,
    int ttsEnd = 0,
    int focusStart = 0,
    int focusEnd = 0,
    double focusAlpha = 0,
    int rangeStart = 0,
    int? rangeEnd,
  }) {
    return ReadingSpans.build(
      text: text,
      prov: p,
      baseStyle: base,
      brightness: Brightness.light,
      highlights: highlights,
      ttsActive: ttsActive,
      ttsStart: ttsStart,
      ttsEnd: ttsEnd,
      focusStart: focusStart,
      focusEnd: focusEnd,
      focusAlpha: focusAlpha,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  String flatten(List<TextSpan> spans) => spans.map((s) => s.text ?? '').join();

  group('ReadingSpans — text preservation', () {
    const text = 'The quick brown fox jumps over the lazy dog.';

    test('undecorated text is one span covering everything', () {
      final spans = build(text);
      expect(spans, hasLength(1));
      expect(spans.single.text, text);
    });

    test('highlights never lose or duplicate a character', () {
      final spans = build(text, highlights: [hl(4, 9), hl(20, 25)]);
      expect(flatten(spans), text);
    });

    test('a TTS sentence never loses or duplicates a character', () {
      final spans = build(text, ttsActive: true, ttsStart: 10, ttsEnd: 19);
      expect(flatten(spans), text);
    });

    test('overlapping highlight and TTS still reproduce the text', () {
      final spans = build(
        text,
        highlights: [hl(4, 15)],
        ttsActive: true,
        ttsStart: 10,
        ttsEnd: 25,
      );
      expect(flatten(spans), text);
    });

    test('adjacent highlights reproduce the text', () {
      final spans = build(text, highlights: [hl(0, 10), hl(10, 20)]);
      expect(flatten(spans), text);
    });
  });

  group('ReadingSpans — decoration', () {
    const text = 'The quick brown fox jumps over the lazy dog.';

    test('the highlighted range gets a background, the rest does not', () {
      final spans = build(text, highlights: [hl(4, 9)]);
      final decorated = spans.where((s) => s.style?.backgroundColor != null);
      expect(decorated, isNotEmpty);
      expect(flatten(decorated.toList()), 'quick');
    });

    test('text outside the highlight keeps the base style', () {
      final spans = build(text, highlights: [hl(4, 9)]);
      final plain = spans.where((s) => s.style?.backgroundColor == null);
      expect(
        flatten(plain.toList()),
        'The  brown fox jumps over the lazy dog.',
      );
    });

    test('an inactive TTS range is not decorated', () {
      final spans = build(text, ttsActive: false, ttsStart: 4, ttsEnd: 9);
      expect(spans, hasLength(1));
      expect(spans.single.style?.backgroundColor, isNull);
    });

    test('a zero-length TTS range decorates nothing', () {
      final spans = build(text, ttsActive: true, ttsStart: 5, ttsEnd: 5);
      expect(flatten(spans), text);
      expect(spans.every((s) => s.style?.backgroundColor == null), isTrue);
    });

    test('a focus flash range gets a background', () {
      final spans = build(
        text,
        focusStart: 4,
        focusEnd: 9,
        focusAlpha: 0.55,
      );
      final decorated = spans.where((s) => s.style?.backgroundColor != null);
      expect(decorated, isNotEmpty);
      expect(flatten(decorated.toList()), 'quick');
    });

    test('zero focus alpha paints nothing', () {
      final spans = build(text, focusStart: 4, focusEnd: 9, focusAlpha: 0);
      expect(spans.every((s) => s.style?.backgroundColor == null), isTrue);
    });

    test('focus flash preserves full text with highlights', () {
      final spans = build(
        text,
        highlights: [hl(16, 19)],
        focusStart: 4,
        focusEnd: 9,
        focusAlpha: 0.4,
      );
      expect(flatten(spans), text);
    });
  });

  group('ReadingSpans — ranges (the pagination path)', () {
    const text = 'The quick brown fox jumps over the lazy dog.';

    test('a range emits only its own slice', () {
      final spans = build(text, rangeStart: 4, rangeEnd: 9);
      expect(flatten(spans), 'quick');
    });

    test('concatenated page ranges equal the full range', () {
      final highlights = [hl(4, 9), hl(20, 30)];
      final full = flatten(build(text, highlights: highlights));
      final paged = [
        build(text, highlights: highlights, rangeStart: 0, rangeEnd: 15),
        build(text, highlights: highlights, rangeStart: 15, rangeEnd: 32),
        build(text, highlights: highlights, rangeStart: 32),
      ].expand((s) => s).toList();
      expect(flatten(paged), full);
      expect(flatten(paged), text);
    });

    test('a highlight straddling a boundary decorates both sides', () {
      // Highlight 4..25 split at 15.
      final left = build(
        text,
        highlights: [hl(4, 25)],
        rangeStart: 0,
        rangeEnd: 15,
      );
      final right = build(
        text,
        highlights: [hl(4, 25)],
        rangeStart: 15,
        rangeEnd: 43,
      );

      String decorated(List<TextSpan> s) =>
          flatten(s.where((x) => x.style?.backgroundColor != null).toList());

      expect(decorated(left), 'quick brown');
      expect(decorated(right), ' fox jumps');
    });

    test('a highlight entirely outside the range is ignored', () {
      final spans = build(text, highlights: [hl(0, 3)], rangeStart: 20);
      expect(spans.every((s) => s.style?.backgroundColor == null), isTrue);
    });

    test('an empty range yields no spans', () {
      expect(build(text, rangeStart: 10, rangeEnd: 10), isEmpty);
      expect(build(''), isEmpty);
    });

    test('out-of-bounds ranges are clamped rather than throwing', () {
      expect(flatten(build(text, rangeStart: -50, rangeEnd: 9999)), text);
      expect(build(text, rangeStart: 9999), isEmpty);
    });

    test('a highlight past the end of the text does not throw', () {
      final spans = build(text, highlights: [hl(9000, 9100)]);
      expect(flatten(spans), text);
    });

    test('a negative highlight offset does not throw', () {
      final spans = build(text, highlights: [hl(-20, 5)]);
      expect(flatten(spans), text);
    });
  });

  group('ReadingSpans — bionic mode', () {
    const text = 'The quick brown fox';
    const bionic = ThemeState(bionicReading: true);

    test('bionic mode splits into more spans but keeps the text', () {
      final plain = build(text);
      final bold = build(text, p: bionic);
      expect(bold.length, greaterThan(plain.length));
      expect(flatten(bold), text);
    });

    test('bionic + highlight still reproduces the text', () {
      final spans = build(text, p: bionic, highlights: [hl(4, 9)]);
      expect(flatten(spans), text);
    });

    test('bionic respects a page range', () {
      final spans = build(text, p: bionic, rangeStart: 4, rangeEnd: 9);
      expect(flatten(spans), 'quick');
    });
  });

  group('TextExtractor.extractCached', () {
    setUp(TextExtractor.invalidate);

    test('returns the same result as the uncached call', () {
      const html = '<p>Hello <b>world</b>.</p><p>Second.</p>';
      expect(
        TextExtractor.extractCached(1, html),
        TextExtractor.extractFromHtml(html),
      );
    });

    test('a hit returns the first result, keyed by chapter id', () {
      final first = TextExtractor.extractCached(7, '<p>Original.</p>');
      // Same id, different html: the cached value wins, proving no re-parse.
      final second = TextExtractor.extractCached(7, '<p>Different.</p>');
      expect(second, first);
      expect(second, 'Original.');
    });

    test('different ids are cached independently', () {
      expect(TextExtractor.extractCached(1, '<p>One.</p>'), 'One.');
      expect(TextExtractor.extractCached(2, '<p>Two.</p>'), 'Two.');
      expect(TextExtractor.extractCached(1, '<p>ignored</p>'), 'One.');
    });

    test('invalidate(id) drops just that entry', () {
      TextExtractor.extractCached(1, '<p>One.</p>');
      TextExtractor.extractCached(2, '<p>Two.</p>');
      TextExtractor.invalidate(1);
      expect(TextExtractor.extractCached(1, '<p>Fresh.</p>'), 'Fresh.');
      expect(TextExtractor.extractCached(2, '<p>ignored</p>'), 'Two.');
    });

    test('invalidate() clears everything', () {
      TextExtractor.extractCached(1, '<p>One.</p>');
      TextExtractor.invalidate();
      expect(TextExtractor.extractCached(1, '<p>Fresh.</p>'), 'Fresh.');
    });

    test('evicts the least-recently-used entry past capacity', () {
      for (var i = 0; i < 12; i++) {
        TextExtractor.extractCached(i, '<p>Chapter $i.</p>');
      }
      // Touch 0 so it is no longer the oldest, then overflow by one.
      expect(TextExtractor.extractCached(0, '<p>ignored</p>'), 'Chapter 0.');
      TextExtractor.extractCached(99, '<p>New.</p>');

      // 0 was refreshed and survives; 1 was the oldest and was evicted.
      expect(TextExtractor.extractCached(0, '<p>ignored</p>'), 'Chapter 0.');
      expect(TextExtractor.extractCached(1, '<p>Refetched.</p>'), 'Refetched.');
    });

    test('empty html stays empty', () {
      expect(TextExtractor.extractCached(1, ''), '');
    });
  });
}
