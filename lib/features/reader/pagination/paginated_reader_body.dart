import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/chapter.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/koma_package_store.dart';
import '../../../core/utils/text_extractor.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_state.dart';
import '../../../widgets/loading_skeleton.dart';
import '../html/kir_model.dart';
import '../layout/kre_layout.dart';
import '../layout/kre_page_view.dart';
import '../layout/reading_font_file.dart';
import '../sheet/sheet_switcher.dart';
import 'book_page_cursor.dart';
import 'chapter_paginator.dart';
import 'paginated_chapter_view.dart';
import 'reading_spans.dart';
import 'resume_resolver.dart';

/// The paginated reader body: measures each chapter into screen-sized sheets
/// and turns between them with [SheetSwitcher].
///
/// ## Why the sheet index is not a book-wide page number
///
/// [SheetSwitcher] addresses sheets with a single int, but a book-wide page
/// number would mean paginating every chapter up front just to know where
/// chapter N starts — which defeats [BookPageCursor]'s lazy per-chapter
/// measurement.
///
/// The int is an opaque monotonic counter mapped onto relative cursor moves.
/// A neighbour step that returns null is how a turn is refused at the ends
/// of the book.
class PaginatedReaderBody extends StatefulWidget {
  const PaginatedReaderBody({
    super.key,
    required this.chapters,
    required this.chapterIndex,
    required this.themeProv,
    required this.charOffsetFor,
    required this.pixelOffsetFor,
    this.contentHeightFor,
    this.highlights = const [],
    this.highlightVersion = 0,
    this.ttsActive = false,
    this.ttsStart = 0,
    this.ttsEnd = 0,
    this.contentListenable,
    this.ttsActiveForBuild,
    this.ttsStartForBuild,
    this.ttsEndForBuild,
    this.focusStart = 0,
    this.focusEnd = 0,
    this.focusAlpha = 0,
    this.focusAnimation,
    this.focusAlphaForValue,
    this.overrideCharOffset,
    this.onOverrideApplied,
    this.onPositionChanged,
    this.onChapterChanged,
    this.onSelected,
    this.onSelectionCleared,
    this.onSelectionCollapsed,
    this.kirForChapter,
    this.bookId,
    this.sheetColor,
    this.disableAnimations = false,
  });

  final List<Chapter> chapters;

  /// Chapter the host reader considers current. A change that did not originate
  /// from a page turn (chapter list tap, next/previous chapter button) re-seeks.
  final int chapterIndex;

  final ThemeState themeProv;

  /// Stored resume sources, forwarded to [ResumeResolver].
  final int? Function(int chapterIndex) charOffsetFor;
  final double Function(int chapterIndex) pixelOffsetFor;
  final double? Function(int chapterIndex)? contentHeightFor;

  final List<Highlight> highlights;
  final int highlightVersion;

  final bool ttsActive;
  final int ttsStart;
  final int ttsEnd;
  final Listenable? contentListenable;
  final bool Function()? ttsActiveForBuild;
  final int Function()? ttsStartForBuild;
  final int Function()? ttsEndForBuild;
  final int focusStart;
  final int focusEnd;
  final double focusAlpha;
  final Animation<double>? focusAnimation;
  final double Function(double value)? focusAlphaForValue;

  /// When set, the next [_seed] opens at this chapter char offset instead of the
  /// stored resume position (snippet jump). Host clears it via
  /// [onOverrideApplied] after the first successful seed.
  final int? overrideCharOffset;
  final VoidCallback? onOverrideApplied;

  /// Fires on every settled page turn with the new position and the character
  /// offset that page starts at. [exact] is false only when the offset was
  /// approximated from a legacy pixel position, which the host should persist
  /// straight away so the approximation happens once.
  final void Function(
    BookPosition position,
    int charOffset, {
    required bool exact,
    int? pageEnd,
  })?
  onPositionChanged;

  /// Fires when a turn crosses into a different chapter.
  final ValueChanged<int>? onChapterChanged;

  final void Function(int start, int end)? onSelected;
  final VoidCallback? onSelectionCleared;
  final VoidCallback? onSelectionCollapsed;

  /// Optional KIR per chapter index (Level 1). Null → HTML [TextExtractor].
  final KirChapter? Function(int chapterIndex)? kirForChapter;

  /// When set, page mode lays out through KRE ([KomaPackageStore.layoutPages])
  /// and paints [KrePageView]. Null or a failed layout falls back to Flutter
  /// [ChapterPaginator].
  final int? bookId;

  /// Opaque sheet fill. Defaults to [ThemeState.bgColor].
  final Color? sheetColor;

  /// Instant sheet swap (reduce-motion / tests).
  final bool disableAnimations;

  @override
  State<PaginatedReaderBody> createState() => _PaginatedReaderBodyState();
}

class _PaginatedReaderBodyState extends State<PaginatedReaderBody> {
  BookPageCursor? _cursor;
  late BookPosition _position;

  /// Opaque monotonic counter for [_position]. Only differences matter.
  int _sheetIndex = 0;
  SheetTurnDirection _sheetDirection = SheetTurnDirection.none;
  Offset? _panStart;
  Duration? _panStartAt;
  int _pointerDowns = 0;
  bool _sawMultiTouch = false;
  bool _imageZoomed = false;

  /// Set once the first layout has resolved a resume position, so build knows
  /// whether [_position] is meaningful yet.
  bool _seeded = false;

  /// Guards against re-seeking to a chapter we ourselves just turned into.
  int _lastHostChapter = -1;

  Size _viewport = Size.zero;

  /// Text scaler in force, captured in build so measurement outside the build
  /// phase (the settle timer) uses the same value the pages render with.
  TextScaler _textScaler = TextScaler.noScaling;

  /// The key the cached pagination was measured against, so a change can be
  /// detected in build — where derived measurements are already up to date.
  PaginationKey? _measuredKey;

  /// True while reading settings are still changing. Neighbouring chapters are
  /// not measured during this window; see [_pageAt].
  bool _settling = false;
  Timer? _settleTimer;
  int _warmGeneration = 0;
  final Set<int> _warmingChapters = {};

  /// KRE layout by chapter index. Missing entry means not yet requested or
  /// still in flight; [_kreFailed] means use Flutter measurement.
  final Map<int, LayoutResult> _kreLayouts = {};
  final Map<int, PaginationKey> _kreKeys = {};
  final Set<int> _kreFailed = {};
  final Set<int> _kreLoading = {};
  int _kreGeneration = 0;

  /// Character offset to restore after a settings-driven KRE relayout.
  int? _heldOffset;

  @override
  void initState() {
    super.initState();
    _position = BookPosition(widget.chapterIndex, 0);
    _lastHostChapter = widget.chapterIndex;
  }

  @override
  void didUpdateWidget(PaginatedReaderBody old) {
    super.didUpdateWidget(old);

    // A settings change is handled in build, not here: re-measuring needs the
    // title inset for the *new* settings, which is only computed once the build
    // phase has laid the title out.
    if (_keyFor(_viewport) != _keyFor(_viewport, prov: old.themeProv)) {
      _markSettling();
    }

    if (!identical(widget.chapters, old.chapters) ||
        widget.bookId != old.bookId) {
      _cursor = null;
      _measuredKey = null;
      _seeded = false;
      _warmGeneration++;
      _warmingChapters.clear();
      _clearKre();
    }

    // A chapter change the host initiated (not one of our page turns).
    if (widget.chapterIndex != _lastHostChapter &&
        widget.chapterIndex != _position.chapterIndex) {
      _lastHostChapter = widget.chapterIndex;
      _seeded = false;
    } else {
      _lastHostChapter = widget.chapterIndex;
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  PaginationKey _keyFor(Size viewport, {ThemeState? prov}) =>
      PaginationKey.from(prov ?? widget.themeProv, viewport);

  /// Builds (or rebuilds) the cursor for the current viewport and settings.
  ///
  /// The span builder closes over the same [ReadingSpans] the page renders, so
  /// measurement and rendering cannot disagree — including bionic bold, which
  /// changes glyph widths.
  ///
  /// The style is resolved inside the builder rather than captured here: the
  /// cursor outlives settings changes, and a captured style would keep
  /// re-measuring against the font the reader was opened with.
  ///
  /// Keying is left to the caller: [_applyKeyChange] has to read the outgoing
  /// pagination before it is discarded, so this must not clear the cache.
  BookPageCursor _cursorFor(Size viewport) {
    final existing = _cursor;
    if (existing != null) return existing;

    final cursor = BookPageCursor(
      chapters: widget.chapters,
      deferMeasure: widget.bookId == null
          ? null
          : (i) => !_kreFailed.contains(i) && !_kreLayouts.containsKey(i),
      paginatorFor: (i) {
        final chapter = widget.chapters[i];
        final doc = TextExtractor.documentCached(
          chapter.id,
          chapter.content,
          kir: widget.kirForChapter?.call(i),
        );
        final baseStyle = ReadingSpans.style(
          widget.themeProv,
          context.colors.textPrimary,
        );
        final width = _viewport.width > 0 ? _viewport.width : 360.0;
        return ChapterPaginator(
          spanBuilder: (start, end) => ReadingSpans.buildFromDocument(
            doc: doc,
            prov: widget.themeProv,
            baseStyle: baseStyle,
            brightness: Theme.of(context).brightness,
            // Highlights and TTS tint colour only — they never change metrics,
            // and excluding them keeps pagination stable as they change.
            rangeStart: start,
            rangeEnd: end,
            contentWidth: width,
            includeImages: true,
            applyHeadingMetrics: true,
          ),
          // Measured per chapter: titles wrap to different heights, so sharing
          // one inset would mis-measure every chapter but the one it came from.
          firstPageInset: _titleInsetFor(i),
        );
      },
    );
    _cursor = cursor;
    return cursor;
  }

  /// Height reserved above the first page of [chapterIndex] for its title.
  double _titleInsetFor(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= widget.chapters.length) return 28;
    if (_viewport.width <= 0) return 28;
    return PaginatedChapterView.titleInsetFor(
      context,
      widget.themeProv,
      widget.chapters[chapterIndex].title,
      _viewport.width,
      textScaler: _textScaler,
    );
  }

  void _clearKre() {
    _kreGeneration++;
    _kreLayouts.clear();
    _kreKeys.clear();
    _kreFailed.clear();
    _kreLoading.clear();
  }

  bool _krePending(int chapterIndex) =>
      widget.bookId != null &&
      !_kreFailed.contains(chapterIndex) &&
      !_kreLayouts.containsKey(chapterIndex);

  void _installKre(BookPageCursor cursor, PaginationKey key, int chapterIndex) {
    final layout = _kreLayouts[chapterIndex];
    if (layout == null) return;
    cursor.putPages(
      chapterIndex,
      PaginatedChapter.fromLayout(
        chapterId: widget.chapters[chapterIndex].id,
        layout: layout,
        key: key,
      ),
    );
  }

  /// Fire KRE layout for [chapterIndex] if this book has a `.koma`.
  void _requestKre(int chapterIndex, PaginationKey key) {
    final bookId = widget.bookId;
    if (bookId == null ||
        chapterIndex < 0 ||
        chapterIndex >= widget.chapters.length ||
        _kreFailed.contains(chapterIndex) ||
        _kreKeys[chapterIndex] == key ||
        !_kreLoading.add(chapterIndex)) {
      return;
    }
    final gen = _kreGeneration;
    final width = _viewport.width.floor().clamp(1, 100000);
    final height = _viewport.height.floor().clamp(1, 100000);
    final fontSize = _textScaler.scale(widget.themeProv.fontSize);
    final lineHeightPx = fontSize * widget.themeProv.lineHeight;
    final inset = _titleInsetFor(chapterIndex);
    final theme = widget.themeProv;
    () async {
      var fontPath = '';
      try {
        fontPath = await readingFontFilePath(theme) ?? '';
      } catch (_) {}
      if (!mounted || gen != _kreGeneration) return null;
      return KomaPackageStore.layoutPages(
        bookId: bookId,
        index: chapterIndex,
        width: width,
        height: height,
        fontSize: fontSize,
        lineHeight: lineHeightPx,
        margin: 0,
        firstPageInset: inset,
        fontPath: fontPath,
      );
    }().then((layout) {
      if (!mounted || gen != _kreGeneration) return;
      _kreLoading.remove(chapterIndex);
      if (layout == null || layout.pages.isEmpty) {
        _kreFailed.add(chapterIndex);
        setState(() {});
        return;
      }
      _kreLayouts[chapterIndex] = layout;
      _kreKeys[chapterIndex] = key;
      final cursor = _cursor;
      if (cursor != null) {
        _installKre(cursor, key, chapterIndex);
        if (_position.chapterIndex == chapterIndex) {
          final offset =
              _heldOffset ??
              widget.charOffsetFor(chapterIndex) ??
              cursor.offsetAt(_position);
          _position = cursor.positionForOffset(chapterIndex, offset);
          _seeded = true;
        }
      }
      setState(() {});
    });
  }

  /// Opens the "settings are changing" window, during which only the chapter
  /// being read is measured. Each further change pushes the window out, so a
  /// slider drag re-measures one chapter per step instead of three.
  void _markSettling() {
    _settling = true;
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _settling = false);
    });
  }

  /// Re-measures against [key], keeping the reader on the same text by carrying
  /// the current page's character offset across the change.
  ///
  /// Called from build so the per-chapter title inset it measures with reflects
  /// the settings being applied, not the ones being replaced.
  void _applyKeyChange(BookPageCursor cursor, PaginationKey key) {
    final offset = _seeded ? cursor.offsetAt(_position) : 0;
    cursor.updateKey(key);
    _measuredKey = key;
    _warmGeneration++;
    _warmingChapters.clear();
    _kreGeneration++;
    _kreLoading.clear();
    _kreFailed.clear();
    // Keep [_kreLayouts] so a chrome/inset flicker does not flash the
    // skeleton. [_requestKre] refetches when [_kreKeys] no longer match.
    if (_seeded) {
      _heldOffset = offset;
      if (widget.bookId == null) {
        _position = cursor.positionForOffset(_position.chapterIndex, offset);
      }
    }
  }

  /// Resolves where to open the chapter the host asked for, once per seek.
  void _seed(BookPageCursor cursor) {
    final override = widget.overrideCharOffset;
    if (override != null) {
      _position = cursor.positionForOffset(widget.chapterIndex, override);
      _seeded = true;
      widget.onOverrideApplied?.call();
      widget.onPositionChanged?.call(
        _position,
        override,
        exact: true,
        pageEnd: cursor.pageAt(_position).end,
      );
      return;
    }

    final resolver = ResumeResolver(
      cursor: cursor,
      charOffsetFor: widget.charOffsetFor,
      pixelOffsetFor: widget.pixelOffsetFor,
      contentHeightFor: widget.contentHeightFor ?? (_) => null,
    );
    final target = resolver.resolve(widget.chapterIndex);
    _position = target.position;
    _seeded = true;

    // An approximated position should be written back as a character offset so
    // the pixel guess is never repeated for this chapter.
    if (!target.exact) {
      widget.onPositionChanged?.call(
        _position,
        cursor.offsetAt(_position),
        exact: false,
        pageEnd: cursor.pageAt(_position).end,
      );
    }
  }

  void _turnSheet({required bool forward}) {
    final cursor = _cursor;
    if (cursor == null) return;
    final step = forward ? cursor.next(_position) : cursor.previous(_position);
    if (step == null) return;

    final previousChapter = _position.chapterIndex;
    setState(() {
      _position = step;
      _sheetIndex += forward ? 1 : -1;
      _sheetDirection = forward
          ? SheetTurnDirection.forward
          : SheetTurnDirection.back;
      _imageZoomed = false;
    });

    widget.onPositionChanged?.call(
      step,
      cursor.offsetAt(step),
      exact: true,
      pageEnd: cursor.pageAt(step).end,
    );
    if (step.chapterIndex != previousChapter) {
      widget.onChapterChanged?.call(step.chapterIndex);
    }
  }

  /// Whether stepping once from [pos] toward [delta] stays inside the chapter,
  /// avoiding a measure of a fresh chapter.
  bool _staysInChapter(BookPageCursor cursor, BookPosition pos, int delta) {
    if (delta > 0) {
      return pos.pageIndex + 1 < cursor.pageCountOf(pos.chapterIndex);
    }
    return pos.pageIndex > 0;
  }

  void _warmNeighborChapters(BookPageCursor cursor) {
    if (_settling || !_seeded) return;
    final generation = _warmGeneration;
    for (final chapterIndex in [
      _position.chapterIndex - 1,
      _position.chapterIndex + 1,
    ]) {
      if (chapterIndex < 0 || chapterIndex >= widget.chapters.length) {
        continue;
      }
      if (widget.bookId != null && !_kreFailed.contains(chapterIndex)) {
        _requestKre(chapterIndex, _keyFor(_viewport));
        continue;
      }
      if (cursor.isPaginated(chapterIndex) ||
          !_warmingChapters.add(chapterIndex)) {
        continue;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (!mounted ||
              generation != _warmGeneration ||
              _settling ||
              !identical(cursor, _cursor)) {
            return;
          }
          cursor.pagesFor(chapterIndex);
        } finally {
          _warmingChapters.remove(chapterIndex);
        }
      });
    }
  }

  Widget? _pageAt(BookPageCursor cursor, int delta) {
    var pos = _position;
    for (var i = 0; i < delta.abs(); i++) {
      // While settings are still changing, decline neighbours that would force
      // a fresh chapter to be measured — the pagination is about to be thrown
      // away by the next change anyway. The page being read is always built
      // (delta 0), so the reader never sees a gap.
      if (_settling && !_staysInChapter(cursor, pos, delta)) return null;
      final step = delta > 0 ? cursor.next(pos) : cursor.previous(pos);
      if (step == null) return null;
      pos = step;
    }

    final isCurrentChapter = pos.chapterIndex == widget.chapterIndex;

    if (widget.bookId != null && !_kreFailed.contains(pos.chapterIndex)) {
      _requestKre(pos.chapterIndex, _keyFor(_viewport));
      if (_krePending(pos.chapterIndex)) {
        return _krePlaceholder();
      }
    }

    Widget buildPage(double focusAlpha) {
      final kre = _kreLayouts[pos.chapterIndex];
      if (kre != null && pos.pageIndex < kre.pages.length) {
        return _krePageAt(pos, kre, isCurrentChapter, focusAlpha);
      }

      final page = cursor.pageAt(pos);
      if (page.isEmpty) return const SizedBox.shrink();
      final chapter = widget.chapters[pos.chapterIndex];
      final doc = TextExtractor.documentCached(
        chapter.id,
        chapter.content,
        kir: widget.kirForChapter?.call(pos.chapterIndex),
      );
      return PaginatedChapterView(
        text: doc.plainText,
        document: doc,
        page: page,
        chapterTitle: chapter.title,
        showTitle: pos.pageIndex == 0,
        themeProv: widget.themeProv,
        contentWidth: _viewport.width,
        highlights: isCurrentChapter ? widget.highlights : const [],
        highlightVersion: widget.highlightVersion,
        ttsActive:
            (widget.ttsActiveForBuild?.call() ?? widget.ttsActive) &&
            isCurrentChapter,
        ttsStart: widget.ttsStartForBuild?.call() ?? widget.ttsStart,
        ttsEnd: widget.ttsEndForBuild?.call() ?? widget.ttsEnd,
        focusStart: isCurrentChapter ? widget.focusStart : 0,
        focusEnd: isCurrentChapter ? widget.focusEnd : 0,
        focusAlpha: isCurrentChapter ? focusAlpha : 0,
        onSelected: widget.onSelected,
        onSelectionCleared: widget.onSelectionCleared,
        onSelectionCollapsed: widget.onSelectionCollapsed,
      );
    }

    final focusAnimation = widget.focusAnimation;
    final listenables = <Listenable>[
      if (widget.contentListenable != null) widget.contentListenable!,
      if (isCurrentChapter &&
          focusAnimation != null &&
          widget.focusEnd > widget.focusStart)
        focusAnimation,
    ];
    if (listenables.isNotEmpty) {
      return AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (_, _) => buildPage(
          isCurrentChapter && focusAnimation != null
              ? widget.focusAlphaForValue?.call(focusAnimation.value) ??
                    widget.focusAlpha
              : widget.focusAlpha,
        ),
      );
    }
    return buildPage(widget.focusAlpha);
  }

  Widget _krePlaceholder() {
    return ColoredBox(
      color: widget.sheetColor ?? widget.themeProv.bgColor,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: double.infinity, height: 18),
            SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 18),
            SizedBox(height: 12),
            Skeleton(width: 220, height: 18),
          ],
        ),
      ),
    );
  }

  Widget _krePageAt(
    BookPosition pos,
    LayoutResult layout,
    bool isCurrentChapter,
    double focusAlpha,
  ) {
    final chapter = widget.chapters[pos.chapterIndex];
    final doc = TextExtractor.documentCached(
      chapter.id,
      chapter.content,
      kir: widget.kirForChapter?.call(pos.chapterIndex),
    );
    return KrePageView(
      page: layout.pages[pos.pageIndex],
      plainText: layout.plainText,
      document: doc,
      chapterTitle: chapter.title,
      showTitle: pos.pageIndex == 0 &&
          !layout.pages[pos.pageIndex].isImageOnly,
      themeProv: widget.themeProv,
      highlights: isCurrentChapter ? widget.highlights : const [],
      highlightVersion: widget.highlightVersion,
      ttsActive:
          (widget.ttsActiveForBuild?.call() ?? widget.ttsActive) &&
          isCurrentChapter,
      ttsStart: widget.ttsStartForBuild?.call() ?? widget.ttsStart,
      ttsEnd: widget.ttsEndForBuild?.call() ?? widget.ttsEnd,
      focusStart: isCurrentChapter ? widget.focusStart : 0,
      focusEnd: isCurrentChapter ? widget.focusEnd : 0,
      focusAlpha: isCurrentChapter ? focusAlpha : 0,
      embeds: doc.embeds,
      imageSlotBase: imageSlotBase(layout, pos.pageIndex),
      onSelected: widget.onSelected,
      onSelectionCleared: widget.onSelectionCleared,
      onSelectionCollapsed: widget.onSelectionCollapsed,
      onZoomed: (zoomed) {
        if (!mounted) return;
        _imageZoomed = zoomed;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport.width <= 0 || viewport.height <= 0) {
          return const SizedBox.shrink();
        }

        // Recorded before any measuring: the per-chapter title inset and the
        // span builder both read them.
        _viewport = viewport;
        _textScaler = MediaQuery.textScalerOf(context);

        final cursor = _cursorFor(viewport);
        final key = _keyFor(viewport);
        if (_measuredKey != key) {
          // Covers both a settings change and a resize, since the viewport is
          // part of the key.
          _applyKeyChange(cursor, key);
        }
        if (widget.bookId != null &&
            !_kreFailed.contains(widget.chapterIndex)) {
          _requestKre(widget.chapterIndex, key);
          final layout = _kreLayouts[widget.chapterIndex];
          if (layout != null) _installKre(cursor, key, widget.chapterIndex);
          if (_krePending(widget.chapterIndex)) {
            return _krePlaceholder();
          }
        }
        if (!_seeded) _seed(cursor);
        _warmNeighborChapters(cursor);

        final page = _pageAt(cursor, 0);
        if (page == null) return const SizedBox.shrink();

        return Listener(
          onPointerDown: (event) {
            _pointerDowns++;
            if (_pointerDowns == 1) {
              _panStart = event.position;
              _panStartAt = event.timeStamp;
              _sawMultiTouch = false;
            } else {
              _sawMultiTouch = true;
            }
          },
          onPointerCancel: (_) {
            _pointerDowns = 0;
            _sawMultiTouch = false;
            _panStart = null;
            _panStartAt = null;
          },
          onPointerUp: (event) {
            _pointerDowns = _pointerDowns > 0 ? _pointerDowns - 1 : 0;
            if (_pointerDowns > 0) return;
            final start = _panStart;
            final startedAt = _panStartAt;
            final multi = _sawMultiTouch;
            _panStart = null;
            _panStartAt = null;
            _sawMultiTouch = false;
            if (multi || _imageZoomed) return;
            if (start == null || startedAt == null) return;
            final dx = event.position.dx - start.dx;
            final dy = event.position.dy - start.dy;
            if (dx.abs() < 64 || dx.abs() < dy.abs()) return;
            final dtMs = (event.timeStamp - startedAt).inMilliseconds;
            final vx = dtMs > 0 ? dx / dtMs * 1000 : 0;
            if (vx < -500 || dx < -80) {
              _turnSheet(forward: true);
            } else if (vx > 500 || dx > 80) {
              _turnSheet(forward: false);
            }
          },
          child: SheetSwitcher(
            index: _sheetIndex,
            direction: _sheetDirection,
            sheetColor: widget.sheetColor ?? widget.themeProv.bgColor,
            disableAnimations:
                widget.disableAnimations ||
                MediaQuery.disableAnimationsOf(context),
            child: KeyedSubtree(
              key: ValueKey(_sheetIndex),
              child: page,
            ),
          ),
        );
      },
    );
  }
}
