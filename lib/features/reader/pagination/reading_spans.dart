import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/highlight.dart';
import '../../../theme/theme_state.dart';
import '../../../theme/tokens/app_colors.dart';
import '../../../theme/tokens/app_type.dart';
import '../../../widgets/bionic_text.dart';

/// Builds the styled spans for a stretch of reading text.
///
/// Extracted from `ReaderScreen` so scroll mode and paginated mode share one
/// implementation: scroll mode asks for the whole chapter, paginated mode asks
/// for a single page's character range. Highlight, TTS and bionic behaviour
/// therefore cannot drift between the two.
///
/// All offsets are character offsets into the chapter's extracted plain text —
/// the same coordinate space `Highlight.startOffset` and
/// `TtsProvider.currentSentenceOffset` already use.
class ReadingSpans {
  const ReadingSpans._();

  /// The base text style for reading content.
  static TextStyle style(ThemeState prov, Color textColor) {
    return AppType.fontStyle(
      fontFamily: prov.useDeviceFont ? null : prov.readingFontFamily,
      fontSize: prov.fontSize,
      lineHeight: prov.lineHeight,
      color: textColor,
    );
  }

  /// Spans covering `text[rangeStart..rangeEnd)`.
  ///
  /// [rangeStart]/[rangeEnd] default to the whole of [text]. A highlight or TTS
  /// sentence that straddles the range boundary is rendered on the part that
  /// falls inside it, so a highlight spanning a page break decorates both pages.
  static List<TextSpan> build({
    required String text,
    required ThemeState prov,
    required TextStyle baseStyle,
    required Brightness brightness,
    List<Highlight> highlights = const [],
    bool ttsActive = false,
    int ttsStart = 0,
    int ttsEnd = 0,
    int rangeStart = 0,
    int? rangeEnd,
  }) {
    final start = rangeStart.clamp(0, text.length);
    final end = (rangeEnd ?? text.length).clamp(start, text.length);
    if (start >= end) return const [];

    // Fast path: nothing to decorate, so the range is one uniform span.
    if (highlights.isEmpty && !prov.bionicReading && !ttsActive) {
      return [TextSpan(text: text.substring(start, end), style: baseStyle)];
    }

    // Assemble boundaries from highlights + the spoken TTS sentence, clipped
    // to the requested range.
    final boundaries = <_Boundary>[];
    for (final hl in highlights) {
      final hs = hl.startOffset.clamp(0, text.length);
      final he = hl.endOffset.clamp(0, text.length);
      // Intersect with the range; skip highlights that miss it entirely.
      final s = max(hs, start);
      final e = min(he, end);
      if (e > s) {
        boundaries
          ..add(_Boundary(s, true, hl.color))
          ..add(_Boundary(e, false, hl.color));
      }
    }
    if (ttsActive && ttsEnd > 0 && ttsStart < ttsEnd) {
      final s = max(ttsStart.clamp(0, text.length), start);
      final e = min(ttsEnd.clamp(0, text.length), end);
      if (e > s) {
        boundaries
          ..add(_Boundary(s, true, _ttsKey))
          ..add(_Boundary(e, false, _ttsKey));
      }
    }
    boundaries.sort((a, b) => a.offset.compareTo(b.offset));

    // O(n log n) boundary merge; fine for typical book chapters.
    final spans = <TextSpan>[];
    final activeHighlights = <String>{};
    var ttsOn = false;
    var cursor = start;

    void applyBoundary(_Boundary b) {
      if (b.color == _ttsKey) {
        ttsOn = b.isStart;
      } else if (b.isStart) {
        activeHighlights.add(b.color);
      } else {
        activeHighlights.remove(b.color);
      }
    }

    for (final b in boundaries) {
      if (b.offset > cursor) {
        spans.addAll(
          _segments(
            prov,
            text.substring(cursor, b.offset),
            _decorate(
              baseStyle,
              prov,
              brightness,
              activeHighlights.isEmpty ? null : activeHighlights.first,
              ttsOn,
            ),
          ),
        );
        cursor = b.offset;
      }
      applyBoundary(b);
    }

    if (cursor < end) {
      spans.addAll(
        _segments(
          prov,
          text.substring(cursor, end),
          _decorate(
            baseStyle,
            prov,
            brightness,
            activeHighlights.isEmpty ? null : activeHighlights.first,
            ttsOn,
          ),
        ),
      );
    }
    return spans;
  }

  /// Sentinel colour key marking the TTS sentence, kept distinct from any real
  /// highlight colour name.
  static const String _ttsKey = '_tts';

  /// Applies the highlight background and/or TTS tint to [base].
  static TextStyle _decorate(
    TextStyle base,
    ThemeState prov,
    Brightness brightness,
    String? highlightColor,
    bool ttsOn,
  ) {
    var style = base;
    if (highlightColor != null) {
      style = style.copyWith(
        backgroundColor: AppColors.highlight(
          highlightColor,
          brightness,
          isSepia: false,
        ).withValues(alpha: 0.35),
      );
    }
    if (ttsOn) {
      final bg = style.backgroundColor ?? Colors.transparent;
      style = style.copyWith(
        backgroundColor: Color.lerp(
          bg,
          prov.accentColor.withValues(alpha: 0.15),
          1.0,
        ),
      );
    }
    return style;
  }

  /// Splits [text] into bionic segments when bionic mode is on, otherwise
  /// returns it as a single span.
  static List<TextSpan> _segments(
    ThemeState prov,
    String text,
    TextStyle base,
  ) {
    if (!prov.bionicReading) {
      return [TextSpan(text: text, style: base)];
    }
    return BionicText.spans(
      text,
      baseStyle: base,
      bionicWeight: prov.bionicBoldWeight,
      bionicFraction: prov.bionicBoldFraction,
    );
  }
}

class _Boundary {
  final int offset;
  final bool isStart;
  final String color;

  const _Boundary(this.offset, this.isStart, this.color);
}
