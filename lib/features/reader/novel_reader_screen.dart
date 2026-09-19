import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/highlight.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/providers.dart';
import '../../core/services/novel_html_content_service.dart';
import '../../core/services/security_prefs.dart';
import '../../core/services/trackers/track_chapter_use_case.dart';
import '../../core/services/trackers/track_sync_feedback.dart';
import '../../core/utils/text_extractor.dart';
import '../../features/reader/pagination/highlight_range.dart';
import '../../features/reader/text_progress_pill_prefs.dart';
import '../../features/reader/tts_provider.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/bionic_text.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/reader_bottom_bar.dart';
import '../../widgets/reader_settings_sheet.dart';
import '../../widgets/reader_top_bar.dart';
import '../../widgets/reading_progress_pill.dart';
import '../../widgets/text_selection_toolbar.dart';
import '../../widgets/toast.dart';
import '../../widgets/tts_controls.dart';
import '../../widgets/tts_controls_overlay.dart';

/// HTML novel chapter reader — vertical scroll, manga progress, ebook-like tools.
class NovelReaderScreen extends ConsumerStatefulWidget {
  final int? mangaId;
  final String sourceId;
  final String mangaUrl;
  final String mangaName;
  final String chapterUrl;
  final String chapterName;
  final int? seekStartOffset;
  final int? seekEndOffset;

  const NovelReaderScreen({
    super.key,
    this.mangaId,
    required this.sourceId,
    required this.mangaUrl,
    required this.mangaName,
    required this.chapterUrl,
    required this.chapterName,
    this.seekStartOffset,
    this.seekEndOffset,
  });

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  static const _tapSlop = 18.0;
  static const _autoHideDelay = Duration(seconds: 3);

  String? _html;
  String? _plainText;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = true;
  final _scroll = ScrollController();
  int? _chapterDbId;
  double _pendingScroll = 0;
  int? _pendingCharOffset;
  bool _didRestore = false;
  Timer? _scrollSaveTimer;
  Timer? _uiHideTimer;
  double _liveProgress = 0;
  int _activityTick = 0;
  int _lastActivityMs = 0;
  double _lastScrollOffset = 0;
  Offset? _pointerDown;
  List<MangaChapter> _chapters = const [];
  List<Highlight> _highlights = const [];
  String? _selectedText;
  int? _selStart;
  late final TtsProvider _tts = TtsProvider();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scroll.addListener(_onScrollTick);
    _tts.addListener(_onTtsChanged);
    unawaited(_tts.loadPrefs());
    _load();
  }

  void _onTtsChanged() {
    if (mounted) setState(() {});
    if (_tts.isActive) {
      _cancelUiHideTimer();
      _setChromeVisible(true);
    } else {
      _resetUiHideTimer();
    }
  }

  @override
  void dispose() {
    _scrollSaveTimer?.cancel();
    _uiHideTimer?.cancel();
    unawaited(_flushScroll());
    _scroll.removeListener(_onScrollTick);
    _scroll.dispose();
    _tts.removeListener(_onTtsChanged);
    _tts.dispose();
    super.dispose();
  }

  void _cancelUiHideTimer() {
    _uiHideTimer?.cancel();
    _uiHideTimer = null;
  }

  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) {
      _applySystemUiMode();
      return;
    }
    setState(() => _chromeVisible = visible);
    _applySystemUiMode();
  }

  void _resetUiHideTimer() {
    _cancelUiHideTimer();
    if (!_chromeVisible) {
      _setChromeVisible(true);
    } else {
      _applySystemUiMode();
    }
    final hasSelection =
        _selectedText != null && _selectedText!.trim().isNotEmpty;
    if (ref.read(themeProvider).immersiveAutoHide &&
        !hasSelection &&
        !_tts.isActive) {
      _uiHideTimer = Timer(_autoHideDelay, () {
        if (!mounted || _tts.isActive) return;
        final stillSelecting =
            _selectedText != null && _selectedText!.trim().isNotEmpty;
        if (!stillSelecting) _setChromeVisible(false);
      });
    }
  }

  void _applySystemUiMode() {
    if (!mounted) return;
    final hasSelection =
        _selectedText != null && _selectedText!.trim().isNotEmpty;
    final showSystemUi = _chromeVisible || hasSelection || _tts.isActive;
    SystemChrome.setEnabledSystemUIMode(
      showSystemUi ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _onScrollTick() {
    if (!_scroll.hasClients) return;
    final pixels = _scroll.position.pixels;
    final progress = readingProgressFromScroll(_scroll.position);
    final progressChanged = (progress - _liveProgress).abs() > 0.005;
    if (progressChanged) _liveProgress = progress;

    // Progress pill: pulse only on scroll activity.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastActivityMs > 80) {
      _lastActivityMs = now;
      _activityTick++;
      if (mounted) setState(() {});
    } else if (progressChanged && mounted) {
      setState(() {});
    }

    // Hide chrome while scrolling down (same as ebook).
    final diff = pixels - _lastScrollOffset;
    if (diff > 8 && pixels > 80 && _chromeVisible) {
      _cancelUiHideTimer();
      _setChromeVisible(false);
    }
    _lastScrollOffset = pixels;

    _scheduleScrollSave();
    if (pixels >= _scroll.position.maxScrollExtent - 120) {
      unawaited(_markReadAndSync());
    }
  }

  void _scheduleScrollSave() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      unawaited(_flushScroll());
    });
  }

  Future<void> _flushScroll() async {
    final chapterId = _chapterDbId;
    if (chapterId == null) return;
    if (await SecurityPrefs.isIncognito()) return;
    if (!_scroll.hasClients) return;
    final pixels = _scroll.position.pixels;
    final text = _plainText ?? '';
    int? charOff;
    if (text.isNotEmpty && _scroll.position.maxScrollExtent > 0) {
      final frac = (pixels / _scroll.position.maxScrollExtent).clamp(0.0, 1.0);
      charOff = (frac * text.length).round().clamp(0, text.length);
    }
    await ref.read(repositoriesProvider).manga.updateMangaChapterScrollPosition(
      chapterId,
      pixels,
      readingCharOffset: charOff,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _pointerDown;
    if (start != null && (event.position - start).distance > _tapSlop) {
      _pointerDown = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerDown == null) return;
    _pointerDown = null;
    _onReaderTap();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDown = null;
  }

  void _onReaderTap() {
    if (!mounted) return;
    final hasSelection =
        _selectedText != null && _selectedText!.trim().isNotEmpty;
    if (hasSelection) {
      setState(() {
        _selectedText = null;
        _selStart = null;
      });
      return;
    }
    final next = !_chromeVisible;
    _setChromeVisible(next);
    if (next) {
      _resetUiHideTimer();
    } else {
      _cancelUiHideTimer();
    }
  }

  double _horizontalPadding(double pageWidth) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final leftover = (screenWidth - pageWidth) / 2;
    return leftover < 20 ? 20 : leftover;
  }

  EdgeInsets _readingPadding(ThemeState theme) {
    final mq = MediaQuery.of(context);
    final h = _horizontalPadding(theme.pageWidth);
    final top = mq.viewPadding.top + ReaderTopBar.bodyHeight;
    final bottom = mq.viewPadding.bottom + ReaderBottomBar.bodyHeight;
    final v = math.max(top, bottom);
    return EdgeInsets.fromLTRB(h, v, h, v);
  }

  Future<void> _load({bool forceNetwork = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _didRestore = false;
    });
    try {
      final repos = ref.read(repositoriesProvider);
      final dispatch = ref.read(extensionServiceProvider);
      final mangaId = widget.mangaId ?? 0;
      if (widget.mangaId != null) {
        final existing = await repos.manga.getMangaChapterByUrl(
          widget.mangaId!,
          widget.chapterUrl,
        );
        _chapterDbId = existing?.id;
        _pendingScroll = existing?.scrollPosition ?? 0;
        _pendingCharOffset = existing?.readingCharOffset;
        if (existing != null && !await SecurityPrefs.isIncognito()) {
          await repos.manga.markMangaChapterOpened(existing.id);
        }
        _chapters = await repos.manga.getMangaChapters(widget.mangaId!);
        if (_chapterDbId != null) {
          _highlights = await repos.books.getHighlightsForMangaChapter(
            _chapterDbId!,
          );
        }
      }
      final html = await NovelHtmlContentService(
        repos: repos,
        dispatch: dispatch,
      ).load(
        sourceId: widget.sourceId,
        mangaId: mangaId,
        mangaName: widget.mangaName,
        chapterUrl: widget.chapterUrl,
        forceNetwork: forceNetwork,
      );
      if (!mounted) return;
      final chapterKey = _chapterDbId ?? widget.chapterUrl.hashCode;
      final plain = TextExtractor.extractCached(chapterKey, html);
      setState(() {
        _html = html;
        _plainText = plain;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _restorePosition() {
    if (_didRestore || !_scroll.hasClients) return;
    _didRestore = true;
    final seek = widget.seekStartOffset;
    final text = _plainText ?? '';
    double target = _pendingScroll;
    if (seek != null && text.isNotEmpty && seek >= 0) {
      final frac = (seek / text.length).clamp(0.0, 1.0);
      target = frac * _scroll.position.maxScrollExtent;
    } else if (_pendingCharOffset != null &&
        text.isNotEmpty &&
        _scroll.position.maxScrollExtent > 0) {
      final frac = (_pendingCharOffset! / text.length).clamp(0.0, 1.0);
      target = frac * _scroll.position.maxScrollExtent;
    }
    final clamped = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (clamped > 0) {
      _scroll.jumpTo(clamped);
    }
    setState(() {
      _liveProgress = readingProgressFromScroll(_scroll.position);
    });
    _lastScrollOffset = _scroll.position.pixels;
    _resetUiHideTimer();
  }

  Future<void> _markReadAndSync() async {
    final mangaId = widget.mangaId;
    final chapterId = _chapterDbId;
    if (mangaId == null || chapterId == null) return;
    if (await SecurityPrefs.isIncognito()) return;
    final repos = ref.read(repositoriesProvider);
    await repos.manga.markMangaChapterRead(chapterId);
    final outcome = await TrackChapterUseCase(repos).invoke(
      mangaId: mangaId,
      chapterName: widget.chapterName,
    );
    if (!mounted) return;
    if (outcome != null && outcome.didAnything) {
      ref.read(latestTrackSyncProvider.notifier).setOutcome(outcome);
      final fail = outcome.failureToast;
      if (fail != null) {
        StashToast.show(context, message: fail, icon: Icons.error_outline);
      }
    }
  }

  int get _chapterIndex {
    if (_chapterDbId == null) return -1;
    return _chapters.indexWhere((c) => c.id == _chapterDbId);
  }

  Future<void> _goAdjacent(int delta) async {
    final i = _chapterIndex;
    final next = i + delta;
    if (i < 0 || next < 0 || next >= _chapters.length) return;
    await _flushScroll();
    final ch = _chapters[next];
    if (!mounted) return;
    context.pushReplacementNamed(
      Routes.novelReader,
      extra: (
        mangaId: widget.mangaId,
        sourceId: widget.sourceId,
        mangaUrl: widget.mangaUrl,
        mangaName: widget.mangaName,
        chapterUrl: ch.url,
        chapterName: ch.name,
        seekStartOffset: null,
        seekEndOffset: null,
      ),
    );
  }

  Future<void> _openChapterList() async {
    if (_chapters.isEmpty) return;
    final selected = await showModalBottomSheet<MangaChapter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.6,
            child: ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (_, i) {
                final ch = _chapters[i];
                final active = ch.id == _chapterDbId;
                return ListTile(
                  selected: active,
                  title: Text(
                    ch.name,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: c.textPrimary,
                    ),
                  ),
                  subtitle: ch.scrollPosition > 0 && !ch.isRead
                      ? Text(
                          'In progress',
                          style: TextStyle(color: c.accent, fontSize: 12),
                        )
                      : null,
                  trailing: ch.isRead
                      ? Icon(Icons.check, size: 18, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, ch),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected == null || selected.id == _chapterDbId || !mounted) return;
    await _flushScroll();
    if (!mounted) return;
    context.pushReplacementNamed(
      Routes.novelReader,
      extra: (
        mangaId: widget.mangaId,
        sourceId: widget.sourceId,
        mangaUrl: widget.mangaUrl,
        mangaName: widget.mangaName,
        chapterUrl: selected.url,
        chapterName: selected.name,
        seekStartOffset: null,
        seekEndOffset: null,
      ),
    );
  }

  Future<void> _saveHighlight(String color) async {
    final selected = _selectedText?.trim();
    final mangaId = widget.mangaId;
    final chapterId = _chapterDbId;
    final contentStr = _plainText ?? '';
    if (selected == null ||
        selected.isEmpty ||
        mangaId == null ||
        chapterId == null) {
      return;
    }
    final from = (_selStart != null &&
            _selStart! >= 0 &&
            _selStart! < contentStr.length)
        ? _selStart!
        : 0;
    var startOff = contentStr.indexOf(selected, from);
    if (startOff < 0) startOff = contentStr.indexOf(selected);
    if (startOff < 0) return;
    final end = startOff + selected.length;
    final overlapping = highlightsOverlapping(
      _highlights,
      start: startOff,
      end: end,
    );
    final repos = ref.read(repositoriesProvider);
    for (final h in overlapping) {
      await repos.books.deleteHighlight(h.id);
    }
    final storedId = await repos.books.insertHighlight(
      Highlight(
        id: 0,
        mangaId: mangaId,
        mangaChapterId: chapterId,
        startOffset: startOff,
        endOffset: end,
        color: color,
        text: selected,
      ),
    );
    if (!mounted) return;
    ref.read(themeProvider.notifier).setDefaultHighlight(color);
    setState(() {
      final ids = overlapping.map((h) => h.id).toSet();
      _highlights = [
        ..._highlights.where((h) => !ids.contains(h.id)),
        Highlight(
          id: storedId,
          mangaId: mangaId,
          mangaChapterId: chapterId,
          startOffset: startOff,
          endOffset: end,
          color: color,
          text: selected,
        ),
      ];
      _selectedText = null;
      _selStart = null;
    });
    StashToast.show(context, message: 'Marked', icon: Icons.format_color_fill);
  }

  Future<void> _removeOverlappingHighlights() async {
    final selected = _selectedText?.trim();
    final contentStr = _plainText ?? '';
    if (selected == null || selected.isEmpty) return;
    final from = (_selStart != null &&
            _selStart! >= 0 &&
            _selStart! < contentStr.length)
        ? _selStart!
        : 0;
    var startOff = contentStr.indexOf(selected, from);
    if (startOff < 0) startOff = contentStr.indexOf(selected);
    if (startOff < 0) return;
    final end = startOff + selected.length;
    final overlapping = highlightsOverlapping(
      _highlights,
      start: startOff,
      end: end,
    );
    if (overlapping.isEmpty) return;
    final repos = ref.read(repositoriesProvider);
    for (final h in overlapping) {
      await repos.books.deleteHighlight(h.id);
    }
    if (!mounted) return;
    final ids = overlapping.map((h) => h.id).toSet();
    setState(() {
      _highlights = _highlights.where((h) => !ids.contains(h.id)).toList();
      _selectedText = null;
      _selStart = null;
    });
  }

  bool get _selectionOverlapsHighlight {
    final selected = _selectedText?.trim();
    final contentStr = _plainText ?? '';
    if (selected == null || selected.isEmpty) return false;
    final from = (_selStart != null &&
            _selStart! >= 0 &&
            _selStart! < contentStr.length)
        ? _selStart!
        : 0;
    var startOff = contentStr.indexOf(selected, from);
    if (startOff < 0) startOff = contentStr.indexOf(selected);
    if (startOff < 0) return false;
    return highlightsOverlapping(
      _highlights,
      start: startOff,
      end: startOff + selected.length,
    ).isNotEmpty;
  }

  Future<void> _createSnippet() async {
    final selected = _selectedText?.trim();
    if (selected == null || selected.isEmpty) return;
    final contentStr = _plainText ?? '';
    final from = (_selStart != null &&
            _selStart! >= 0 &&
            _selStart! < contentStr.length)
        ? _selStart!
        : 0;
    var startOff = contentStr.indexOf(selected, from);
    if (startOff < 0) startOff = contentStr.indexOf(selected);
    final scroll = _scroll.hasClients ? _scroll.position.pixels : null;
    await ref.read(snippetsProvider.notifier).createSnippet(
          text: selected,
          sourceTitle: widget.mangaName,
          sourceUrl: widget.chapterUrl,
          mangaId: widget.mangaId,
          mangaChapterId: _chapterDbId,
          startOffset: startOff >= 0 ? startOff : null,
          endOffset: startOff >= 0 ? startOff + selected.length : null,
          scrollPosition: scroll,
        );
    if (!mounted) return;
    setState(() {
      _selectedText = null;
      _selStart = null;
    });
    StashToast.show(context, message: 'Snippet saved', icon: Icons.bookmark);
  }

  Future<void> _toggleTts() async {
    final text = _plainText ?? '';
    if (text.isEmpty) return;
    await _tts.loadPrefs();
    if (!mounted) return;
    if (_tts.isActive) {
      _tts.stop();
      setState(() {});
      return;
    }
    final shouldStart = await TtsSettingsSheet.show(
      context,
      _tts,
      startOnClose: true,
    );
    if (!mounted || !shouldStart) return;
    await _tts.init(text, chapterId: _chapterDbId?.toString());
    if (!mounted) return;
    if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
      final frac =
          (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0.0, 1.0);
      final off = (frac * text.length).round();
      _tts.seekToCharOffset(off);
    } else if (_pendingCharOffset != null && _pendingCharOffset! > 0) {
      _tts.seekToCharOffset(_pendingCharOffset!);
    }
    _tts.playFromCurrent();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = ref.watch(themeProvider);
    final pillPrefs = ref.watch(textProgressPillPrefsProvider);
    final i = _chapterIndex;
    final canPrev = i > 0;
    final canNext = i >= 0 && i < _chapters.length - 1;
    final hasSelection =
        _selectedText != null && _selectedText!.trim().isNotEmpty;
    final showBottomBar = _chromeVisible && !hasSelection;
    final readingPad = _readingPadding(theme);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_error != null)
            Center(
              child: EmptyState(
                icon: AppIcons.cloudLoading,
                title: 'Couldn’t load chapter',
                subtitle: _error,
                primaryActionLabel: 'Retry',
                onPrimaryAction: () => _load(forceNetwork: true),
                pillPrimary: true,
              ),
            )
          else
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: SelectionArea(
                onSelectionChanged: (sel) {
                  final text = sel?.plainText;
                  setState(() {
                    _selectedText = text;
                    _selStart = null;
                  });
                  if (text != null && text.trim().isNotEmpty) {
                    _cancelUiHideTimer();
                    _setChromeVisible(true);
                  }
                },
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: readingPad,
                      sliver: SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: theme.pageWidth,
                            ),
                            child: _NovelBody(
                              html: _html!,
                              chapterId:
                                  _chapterDbId ?? widget.chapterUrl.hashCode,
                              theme: theme,
                              color: c.textPrimary,
                              highlights: _highlights,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: ReadingProgressPillOverlay(
              progress: _liveProgress,
              enabled: pillPrefs.enabled && !_loading && _error == null,
              placement: pillPrefs.placement,
              activityTick: _activityTick,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderTopBar(
              bookTitle: widget.mangaName,
              chapterTitle: widget.chapterName,
              progress: _liveProgress,
              visible: _chromeVisible,
              onBack: () => Navigator.of(context).maybePop(),
              onSettings: () => ReaderSettingsSheet.show(
                context,
                showPageStyle: false,
              ),
              onTtsToggle: _toggleTts,
              isTtsActive: _tts.isActive,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ReaderBottomBar(
              visible: showBottomBar,
              onChapters: _openChapterList,
              onPrevious: () => _goAdjacent(-1),
              onNext: () => _goAdjacent(1),
              canGoPrevious: canPrev,
              canGoNext: canNext,
              currentIndex: i < 0 ? 0 : i,
              totalChapters: _chapters.length,
            ),
          ),
          TtsControlsOverlay(
            provider: _tts,
            chromeVisible: showBottomBar,
          ),
          if (hasSelection)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: ReaderSelectionToolbar(
                selectedColor: theme.defaultHighlight,
                onHighlight: (color) => unawaited(_saveHighlight(color)),
                onRemove: _selectionOverlapsHighlight
                    ? () => unawaited(_removeOverlappingHighlights())
                    : null,
                onNote: () => unawaited(_createSnippet()),
                onCopy: () {
                  final text = _selectedText;
                  if (text != null) {
                    Clipboard.setData(ClipboardData(text: text));
                    StashToast.show(
                      context,
                      message: 'Copied to clipboard',
                      icon: Icons.check,
                    );
                  }
                  setState(() {
                    _selectedText = null;
                    _selStart = null;
                  });
                },
                onShare: () {
                  final text = _selectedText;
                  if (text != null) {
                    Clipboard.setData(ClipboardData(text: text));
                    StashToast.show(
                      context,
                      message: 'Quote copied · share anywhere',
                      icon: Icons.ios_share,
                    );
                  }
                  setState(() {
                    _selectedText = null;
                    _selStart = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NovelBody extends StatelessWidget {
  const _NovelBody({
    required this.html,
    required this.chapterId,
    required this.theme,
    required this.color,
    required this.highlights,
  });

  final String html;
  final int chapterId;
  final ThemeState theme;
  final Color color;
  final List<Highlight> highlights;

  @override
  Widget build(BuildContext context) {
    final text = TextExtractor.extractCached(chapterId, html);
    final baseStyle = AppType.fontStyle(
      fontFamily: theme.effectiveReadingFontFamily,
      fontSize: theme.fontSize,
      lineHeight: theme.lineHeight,
      color: color,
    ).copyWith(letterSpacing: 0.1);

    if (text.trim().isEmpty) {
      return Text(
        'This chapter has no text.',
        style: baseStyle.copyWith(color: color.withValues(alpha: 0.6)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          _novelTextSpan(
            text: text,
            highlights: highlights,
            base: baseStyle,
            bionic: theme.bionicReading,
            bionicWeight: theme.bionicBoldWeight,
            bionicFraction: theme.bionicBoldFraction,
          ),
          textAlign: theme.textAlign,
        ),
        const SizedBox(height: 48),
        Text(
          'End of chapter',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

TextSpan _novelTextSpan({
  required String text,
  required List<Highlight> highlights,
  required TextStyle base,
  required bool bionic,
  required FontWeight bionicWeight,
  required double bionicFraction,
}) {
  if (highlights.isEmpty || text.isEmpty) {
    if (!bionic) return TextSpan(text: text, style: base);
    return TextSpan(
      style: base,
      children: BionicText.spans(
        text,
        baseStyle: base,
        bionicWeight: bionicWeight,
        bionicFraction: bionicFraction,
      ),
    );
  }

  final sorted = [...highlights]
    ..sort((a, b) => a.startOffset.compareTo(b.startOffset));
  final children = <InlineSpan>[];
  var cursor = 0;

  List<InlineSpan> segment(String slice, {Color? wash}) {
    final style = wash == null
        ? base
        : base.copyWith(backgroundColor: wash);
    if (!bionic) return [TextSpan(text: slice, style: style)];
    return BionicText.spans(
      slice,
      baseStyle: style,
      bionicWeight: bionicWeight,
      bionicFraction: bionicFraction,
    );
  }

  for (final h in sorted) {
    final start = h.startOffset.clamp(0, text.length);
    final end = h.endOffset.clamp(0, text.length);
    if (end <= start || start < cursor) continue;
    if (start > cursor) {
      children.addAll(segment(text.substring(cursor, start)));
    }
    final wash = AppColors.highlight(h.color, Brightness.light)
        .withValues(alpha: 0.35);
    children.addAll(segment(text.substring(start, end), wash: wash));
    cursor = end;
  }
  if (cursor < text.length) {
    children.addAll(segment(text.substring(cursor)));
  }
  return TextSpan(style: base, children: children);
}
