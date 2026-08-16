import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/highlight.dart';
import '../../../theme/theme_state.dart';
import '../../../theme/tokens/app_colors.dart';
import '../../../theme/tokens/app_type.dart';
import '../../../widgets/bionic_text.dart';
import '../html/reading_document.dart';

/// Builds the styled spans for a stretch of reading text.
///
/// Scroll mode and paginated mode share this so highlight / TTS / bionic /
/// HTML styles cannot drift. Offsets are into [ReadingDocument.plainText].
class ReadingSpans {
  const ReadingSpans._();

  /// Weight applied to highlighted body text. Headings already at or above
  /// this stay as they are so a mark cannot lighten bold HTML.
  static FontWeight highlightWeight(FontWeight? current) {
    final w = current ?? FontWeight.w400;
    return w.value >= FontWeight.w600.value ? w : FontWeight.w600;
  }

  /// The base text style for reading content.
  static TextStyle style(ThemeState prov, Color textColor) {
    return AppType.fontStyle(
      fontFamily: prov.effectiveReadingFontFamily,
      fontSize: prov.fontSize,
      lineHeight: prov.lineHeight,
      color: textColor,
    );
  }

  /// Plain-text spans (legacy API — no HTML style runs / embeds).
  static List<TextSpan> build({
    required String text,
    required ThemeState prov,
    required TextStyle baseStyle,
    required Brightness brightness,
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
    final spans = buildInline(
      text: text,
      styleRuns: const [],
      embeds: const [],
      prov: prov,
      baseStyle: baseStyle,
      brightness: brightness,
      highlights: highlights,
      ttsActive: ttsActive,
      ttsStart: ttsStart,
      ttsEnd: ttsEnd,
      focusStart: focusStart,
      focusEnd: focusEnd,
      focusAlpha: focusAlpha,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      contentWidth: null,
      includeImages: false,
    );
    return spans.whereType<TextSpan>().toList(growable: false);
  }

  /// Rich spans from a [ReadingDocument] slice, including optional [WidgetSpan]
  /// images when [includeImages] is true and [contentWidth] is set.
  static List<InlineSpan> buildFromDocument({
    required ReadingDocument doc,
    required ThemeState prov,
    required TextStyle baseStyle,
    required Brightness brightness,
    List<Highlight> highlights = const [],
    bool ttsActive = false,
    int ttsStart = 0,
    int ttsEnd = 0,
    int focusStart = 0,
    int focusEnd = 0,
    double focusAlpha = 0,
    int rangeStart = 0,
    int? rangeEnd,
    double? contentWidth,
    bool includeImages = true,
    Color? linkColor,
    void Function(String href)? onLinkTap,
    /// When true, bake heading scale into span styles (paginated / continuous).
    bool applyHeadingMetrics = true,
  }) {
    return buildInline(
      text: doc.plainText,
      styleRuns: doc.styleRuns,
      embeds: doc.embeds,
      blocks: doc.blocks,
      prov: prov,
      baseStyle: baseStyle,
      brightness: brightness,
      highlights: highlights,
      ttsActive: ttsActive,
      ttsStart: ttsStart,
      ttsEnd: ttsEnd,
      focusStart: focusStart,
      focusEnd: focusEnd,
      focusAlpha: focusAlpha,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      contentWidth: contentWidth,
      includeImages: includeImages,
      linkColor: linkColor,
      onLinkTap: onLinkTap,
      applyHeadingMetrics: applyHeadingMetrics,
    );
  }

  /// Core builder: merges HTML style runs with highlight / TTS / focus overlays.
  static List<InlineSpan> buildInline({
    required String text,
    required List<StyleRun> styleRuns,
    required List<ReadingEmbed> embeds,
    List<ReadingBlock> blocks = const [],
    required ThemeState prov,
    required TextStyle baseStyle,
    required Brightness brightness,
    List<Highlight> highlights = const [],
    bool ttsActive = false,
    int ttsStart = 0,
    int ttsEnd = 0,
    int focusStart = 0,
    int focusEnd = 0,
    double focusAlpha = 0,
    int rangeStart = 0,
    int? rangeEnd,
    double? contentWidth,
    bool includeImages = false,
    Color? linkColor,
    void Function(String href)? onLinkTap,
    bool applyHeadingMetrics = true,
  }) {
    final start = rangeStart.clamp(0, text.length);
    final end = (rangeEnd ?? text.length).clamp(start, text.length);
    if (start >= end && !(includeImages && embeds.isNotEmpty)) {
      return const [];
    }

    // Collect absolute offsets where style / decoration changes.
    final cuts = <int>{start, end};
    for (final run in styleRuns) {
      if (run.overlaps(start, end)) {
        cuts.add(run.start.clamp(start, end));
        cuts.add(run.end.clamp(start, end));
      }
    }
    for (final b in blocks) {
      if (b.isHeading && b.hasText) {
        final s = max(b.start, start);
        final e = min(b.end, end);
        if (e > s) {
          cuts.add(s);
          cuts.add(e);
        }
      }
    }
    for (final hl in highlights) {
      final hs = hl.startOffset.clamp(0, text.length);
      final he = hl.endOffset.clamp(0, text.length);
      final s = max(hs, start);
      final e = min(he, end);
      if (e > s) {
        cuts.add(s);
        cuts.add(e);
      }
    }
    if (ttsActive && ttsEnd > 0 && ttsStart < ttsEnd) {
      final s = max(ttsStart.clamp(0, text.length), start);
      final e = min(ttsEnd.clamp(0, text.length), end);
      if (e > s) {
        cuts.add(s);
        cuts.add(e);
      }
    }
    if (focusAlpha > 0 && focusEnd > focusStart) {
      final s = max(focusStart.clamp(0, text.length), start);
      final e = min(focusEnd.clamp(0, text.length), end);
      if (e > s) {
        cuts.add(s);
        cuts.add(e);
      }
    }
    if (includeImages) {
      for (final e in embeds) {
        if (e.afterOffset >= start && e.afterOffset <= end) {
          cuts.add(e.afterOffset.clamp(start, end));
        }
      }
    }

    final sorted = cuts.toList()..sort();
    final spans = <InlineSpan>[];

    // Leading images anchored at `start`.
    if (includeImages && contentWidth != null) {
      spans.addAll(
        _imageSpansAt(
          embeds,
          start,
          contentWidth,
          onlyExact: true,
        ),
      );
    }

    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (b <= a) continue;
      final slice = text.substring(a, b);
      final htmlFlags = _flagsAt(styleRuns, a);
      final hlColor = _highlightAt(highlights, a, text.length);
      final ttsOn = ttsActive && a >= ttsStart && a < ttsEnd;
      final focusOn = focusAlpha > 0 && a >= focusStart && a < focusEnd;
      var style = baseStyle;
      if (applyHeadingMetrics) {
        final heading = _headingAt(blocks, a);
        if (heading != null) {
          final scale = headingScale(heading.kind);
          style = style.copyWith(
            fontSize: (baseStyle.fontSize ?? 16) * scale,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: 0.15,
          );
        }
      }
      style = _applyHtmlFlags(
        style,
        htmlFlags,
        linkColor: linkColor ?? baseStyle.color,
      );
      style = _decorate(
        style,
        prov,
        brightness,
        hlColor,
        ttsOn,
        focusOn: focusOn,
        focusAlpha: focusAlpha,
      );

      GestureRecognizer? recognizer;
      if (htmlFlags.linkHref != null &&
          htmlFlags.linkHref!.isNotEmpty &&
          onLinkTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onLinkTap(htmlFlags.linkHref!);
      }

      spans.addAll(
        _segments(prov, slice, style, recognizer: recognizer),
      );

      if (includeImages && contentWidth != null) {
        spans.addAll(
          _imageSpansAt(embeds, b, contentWidth, onlyExact: true),
        );
      }
    }

    return spans;
  }

  static ReadingBlock? _headingAt(List<ReadingBlock> blocks, int offset) {
    for (final b in blocks) {
      if (b.isHeading && offset >= b.start && offset < b.end) return b;
    }
    return null;
  }

  static StyleFlags _flagsAt(List<StyleRun> runs, int offset) {
    var flags = StyleFlags.empty;
    for (final run in runs) {
      if (offset >= run.start && offset < run.end) {
        flags = flags.merge(run.flags);
      }
    }
    return flags;
  }

  static String? _highlightAt(
    List<Highlight> highlights,
    int offset,
    int textLen,
  ) {
    for (final hl in highlights) {
      final hs = hl.startOffset.clamp(0, textLen);
      final he = hl.endOffset.clamp(0, textLen);
      if (offset >= hs && offset < he) return hl.color;
    }
    return null;
  }

  static TextStyle _applyHtmlFlags(
    TextStyle base,
    StyleFlags flags, {
    Color? linkColor,
  }) {
    var style = base;
    if (flags.bold) {
      style = style.copyWith(fontWeight: FontWeight.w700);
    }
    if (flags.italic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (flags.underline || flags.linkHref != null) {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    if (flags.code) {
      style = style.copyWith(
        fontFamily: 'monospace',
        fontSize: (base.fontSize ?? 16) * 0.92,
      );
    }
    if (flags.linkHref != null && linkColor != null) {
      style = style.copyWith(color: linkColor);
    }
    if (flags.colorHex != null) {
      final parsed = _parseHex(flags.colorHex!);
      if (parsed != null) style = style.copyWith(color: parsed);
    }
    return style;
  }

  static Color? _parseHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  static List<InlineSpan> _imageSpansAt(
    List<ReadingEmbed> embeds,
    int afterOffset,
    double contentWidth, {
    required bool onlyExact,
  }) {
    final out = <InlineSpan>[];
    for (final e in embeds) {
      if (onlyExact ? e.afterOffset != afterOffset : e.afterOffset > afterOffset) {
        continue;
      }
      if (e.afterOffset != afterOffset) continue;
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: contentWidth,
            height: estimateEmbedHeight(e, contentWidth),
            child: _EmbedImage(
              path: e.path,
              maxWidth: contentWidth,
              widthHint: e.widthHint,
              heightHint: e.heightHint,
              isBlock: e.isBlock,
            ),
          ),
        ),
      );
    }
    return out;
  }

  static TextStyle _decorate(
    TextStyle base,
    ThemeState prov,
    Brightness brightness,
    String? highlightColor,
    bool ttsOn, {
    bool focusOn = false,
    double focusAlpha = 0,
  }) {
    var style = base;
    if (highlightColor != null) {
      style = style.copyWith(
        backgroundColor: AppColors.highlightWash(
          highlightColor,
          brightness,
          isSepia: prov.sepiaMode,
        ),
        fontWeight: highlightWeight(style.fontWeight),
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
    // Snippet-arrival flash: yellow wash layered over marks / TTS.
    if (focusOn && focusAlpha > 0) {
      final bg = style.backgroundColor ?? Colors.transparent;
      final flash = AppColors.highlight(
        'yellow',
        brightness,
        isSepia: false,
      ).withValues(alpha: focusAlpha);
      style = style.copyWith(
        backgroundColor: Color.alphaBlend(flash, bg),
      );
    }
    return style;
  }

  static List<TextSpan> _segments(
    ThemeState prov,
    String text,
    TextStyle base, {
    GestureRecognizer? recognizer,
  }) {
    if (!prov.bionicReading) {
      return [
        TextSpan(text: text, style: base, recognizer: recognizer),
      ];
    }
    // Bionic + link: attach recognizer only to the first segment so taps
    // still work without cloning many recognizers.
    final parts = BionicText.spans(
      text,
      baseStyle: base,
      bionicWeight: prov.bionicBoldWeight,
      bionicFraction: prov.bionicBoldFraction,
    );
    if (recognizer == null || parts.isEmpty) return parts;
    return [
      TextSpan(
        text: parts.first.text,
        style: parts.first.style,
        recognizer: recognizer,
      ),
      ...parts.skip(1),
    ];
  }

  /// Opens an http(s) link externally. Relative / empty hrefs are ignored.
  static Future<void> openLink(String href) async {
    final uri = Uri.tryParse(href.trim());
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Scale factor for a heading block kind.
  static double headingScale(ReadingBlockKind kind) {
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

/// Local ebook image with graceful fallback.
class _EmbedImage extends StatelessWidget {
  final String path;
  final double maxWidth;
  final double? widthHint;
  final double? heightHint;
  final bool isBlock;

  const _EmbedImage({
    required this.path,
    required this.maxWidth,
    this.widthHint,
    this.heightHint,
    this.isBlock = true,
  });

  @override
  Widget build(BuildContext context) {
    final filePath = path.startsWith('file:')
        ? Uri.parse(path).toFilePath()
        : path;
    final file = File(filePath);
    final maxW = maxWidth.clamp(32.0, 4000.0);

    Widget placeholder({IconData icon = Icons.broken_image_outlined}) {
      return Container(
        width: maxW,
        height: 72,
        alignment: Alignment.center,
        margin: EdgeInsets.symmetric(vertical: isBlock ? 12 : 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 28, color: Theme.of(context).hintColor),
      );
    }

    if (!file.existsSync()) return placeholder();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isBlock ? 14 : 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Image.file(
            file,
            fit: BoxFit.contain,
            width: widthHint != null && widthHint! < maxW ? widthHint : maxW,
            errorBuilder: (_, _, _) => placeholder(),
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return placeholder(icon: Icons.image_outlined);
            },
          ),
        ),
      ),
    );
  }
}

/// Measures an image's layout height for pagination without decoding twice
/// when hints are present.
double estimateEmbedHeight(ReadingEmbed embed, double contentWidth) {
  final maxW = contentWidth.clamp(32.0, 4000.0);
  if (embed.widthHint != null &&
      embed.heightHint != null &&
      embed.widthHint! > 0) {
    final w = min(embed.widthHint!, maxW);
    return (embed.heightHint! * (w / embed.widthHint!)) +
        (embed.isBlock ? 28 : 8);
  }
  // Soft default until decode; paginator may reflow after first paint.
  return maxW * 0.55 + (embed.isBlock ? 28 : 8);
}

/// Resolves image pixel size from disk for tighter pagination (best-effort).
Future<Size?> probeImageSize(String path) async {
  try {
    final filePath = path.startsWith('file:')
        ? Uri.parse(path).toFilePath()
        : path;
    final bytes = await File(filePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final size = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return size;
  } catch (_) {
    return null;
  }
}
