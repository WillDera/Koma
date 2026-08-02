import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chapter.dart';
import '../../core/models/highlight.dart';
import '../../core/providers.dart';
import '../../core/utils/text_extractor.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/chapter_nav_overlay.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/highlight_color_picker.dart';
import '../../widgets/reader_bottom_bar.dart';
import '../../widgets/reader_settings_sheet.dart';
import '../../widgets/reader_top_bar.dart';
import '../../widgets/text_selection_toolbar.dart';
import '../../widgets/toast.dart';
import '../../widgets/tts_controls.dart';
import 'pagination/paginated_reader_body.dart';
import 'pagination/reading_spans.dart';
import 'reader_provider.dart';
import 'tts_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final int bookId;

  /// Optional target chapter and position for jump-to-snippet navigation.
  ///
  /// [snippetStartOffset]/[snippetEndOffset] are character offsets into the
  /// chapter's extracted text and are the authoritative target: they survive
  /// font, width and reading-mode changes, and are the only form paginated mode
  /// can resolve. [snippetScrollOffset] is a pixel position kept as a fallback
  /// for snippets saved before offsets were recorded.
  final int? snippetChapterId;
  final double? snippetScrollOffset;
  final int? snippetStartOffset;
  final int? snippetEndOffset;

  const ReaderScreen({
    super.key,
    required this.bookId,
    this.snippetChapterId,
    this.snippetScrollOffset,
    this.snippetStartOffset,
    this.snippetEndOffset,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

enum _SwipeDirection { none, next, previous }

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  ReaderNotifier? _provider;

  /// Highlights loaded for the current chapter, used to decorate the
  /// reading text with colored backgrounds.
  List<Highlight> _highlights = [];

  String? _selectedText;

  /// Chapter-relative start offset of the current selection, when the layout
  /// can report it. Paginated mode always can; scroll mode leaves this null and
  /// the save paths fall back to searching from the start of the chapter. The
  /// end is derived from the selected text, so only the start is tracked.
  int? _selStart;

  bool _showUI = true;
  bool _toolbarVisible = false;

  /// Pending dismissal of the quick toolbar after its selection went away.
  /// Held so a new selection can cancel it — see [_showToolbar].
  Timer? _selectionLostTimer;
  bool _colorPickerVisible = false;
  int _highlightVersion = 0;
  double _lastScrollOffset = 0;
  Offset _selectionOrigin = Offset.zero;
  _SwipeDirection _lastSwipeDirection = _SwipeDirection.none;
  double? _dragStartX;

  TtsProvider? _ttsProvider;
  bool _ttsListening = false;
  int _highlightColorIndex = 0;

  /// Index of the chapter we're currently showing. Used to detect a
  /// chapter change after navigation so we can jump the scroll back
  /// to the saved (or 0) position.
  int _lastSeenChapterIndex = -1;

  late final AnimationController _toolbarCtrl;
  late final AnimationController _colorCtrl;

  Timer? _uiHideTimer;
  static const _autoHideDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _toolbarCtrl = AnimationController(vsync: this, duration: AppMotion.sheet);
    _colorCtrl = AnimationController(vsync: this, duration: AppMotion.base);
    _ttsProvider = TtsProvider()..addListener(_onTtsChanged);
    Future.microtask(() => _loadAndRestore());
  }

  void _scheduleDirectionReset() {
    Future.delayed(AppMotion.sheet, () {
      if (mounted) setState(() => _lastSwipeDirection = _SwipeDirection.none);
    });
  }

  void _cancelUiHideTimer() {
    _uiHideTimer?.cancel();
    _uiHideTimer = null;
  }

  void _resetUiHideTimer() {
    _cancelUiHideTimer();
    if (!_showUI) {
      setState(() => _showUI = true);
    }
    _applySystemUiMode();
    if (ref.read(themeProvider).immersiveAutoHide &&
        !_toolbarVisible &&
        !_colorPickerVisible &&
        !(_ttsProvider?.isActive ?? false)) {
      _uiHideTimer = Timer(_autoHideDelay, () {
        if (mounted &&
            !_toolbarVisible &&
            !_colorPickerVisible &&
            !(_ttsProvider?.isActive ?? false)) {
          setState(() => _showUI = false);
          _applySystemUiMode();
        }
      });
    }
  }

  void _applySystemUiMode() {
    if (!mounted) return;
    final showSystemUi =
        _showUI ||
        _toolbarVisible ||
        _colorPickerVisible ||
        (_ttsProvider?.isActive ?? false);
    SystemChrome.setEnabledSystemUIMode(
      showSystemUi ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= ref.read(readerProvider.notifier);
  }

  Future<void> _loadAndRestore() async {
    await _provider!.loadBook(
      widget.bookId,
      targetChapterId: widget.snippetChapterId,
      targetScrollOffset: widget.snippetScrollOffset,
    );
    if (!mounted) return;
    _restoreScrollPosition();
  }

  void _restoreScrollPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        final pos = _provider!.scrollPosition;
        if (pos > 0) {
          _scrollController.jumpTo(
            pos.clamp(0, _scrollController.position.maxScrollExtent),
          );
        }
      }
    });
  }

  /// Called from the Consumer builder when the current chapter index
  /// changes (e.g. next/prev). Drops the scroll to the position saved
  /// for that chapter — or 0 if it has never been visited.
  void _onChapterChanged(int newIndex) {
    if (newIndex == _lastSeenChapterIndex) return;
    _lastSeenChapterIndex = newIndex;
    _lastScrollOffset = 0;
    // Load highlights for this chapter.
    final ch = _provider?.chapters;
    if (ch != null && newIndex >= 0 && newIndex < ch.length) {
      final repos = ref.watch(repositoriesProvider);
      final targetChapterId = ch[newIndex].id;
      repos.books.getHighlightsForChapter(targetChapterId).then((hl) {
        // Stale response: user may have navigated again while this loaded.
        if (!mounted || _provider?.currentChapter?.id != targetChapterId) {
          return;
        }
        // The repository returns a fixed-length list (growable: false), and
        // _saveHighlight appends to it. Rebuild into a growable copy so a new
        // mark can't hit "cannot add to a fixed-length list".
        setState(() => _highlights = List<Highlight>.of(hl));
      });
    } else {
      _highlights = [];
    }
    // Re-init TTS for the new chapter if TTS was active.
    if (_ttsProvider != null && _ttsListening && ch != null) {
      final tts = _ttsProvider!;
      tts.stop();
      tts.init(
        TextExtractor.extractCached(ch[newIndex].id, ch[newIndex].content),
      );
      tts.play();
    }
    // Jump to the saved scroll position for this chapter.  The
    // provider's _scrollPosition may be 0 for an unvisited chapter,
    // but a snippet-jump sets a specific offset (startOffset) that
    // should be used instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _provider?.scrollPosition ?? 0;
      if (pos > 0) {
        _scrollController.jumpTo(
          pos.clamp(0, _scrollController.position.maxScrollExtent),
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _provider?.scrollPosition ?? 0;
      _scrollController.jumpTo(
        pos.clamp(0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  bool _didHandleBack = false;

  void _onTtsChanged() {
    if (!mounted) return;
    // ponytail: defer rebuild to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _applySystemUiMode();
      _scrollToTtsSentence();
      _autoAdvanceChapterOnTtsEnd();
    });
  }

  void _scrollToTtsSentence() {
    final tts = _ttsProvider;
    if (tts == null || !_scrollController.hasClients) return;
    if (!tts.isPlaying && !tts.isPaused) return;
    final text = _currentText;
    if (text.isEmpty) return;
    final offset = tts.currentSentenceOffset;
    if (offset <= 0) return;
    final ratio = offset / text.length;
    final target = ratio * _scrollController.position.maxScrollExtent;
    if ((target - _scrollController.offset).abs() > 60) {
      _scrollController.animateTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _autoAdvanceChapterOnTtsEnd() {
    final tts = _ttsProvider;
    if (tts == null || tts.isPlaying || tts.isPaused) return;
    // ponytail: simple end-of-chapter detection
    if (tts.currentIndex >= tts.totalSentences - 1 && tts.totalSentences > 0) {
      final p = _provider;
      if (p != null && p.currentIndex < p.chapters.length - 1) {
        p.goToNextChapter();
      }
    }
  }

  String get _currentText {
    final ch = _provider?.currentChapter;
    return ch != null ? TextExtractor.extractCached(ch.id, ch.content) : '';
  }

  String get _nextHighlightColor {
    final palette = HighlightColorPicker.palette;
    if (palette.isEmpty) return 'yellow';
    return palette[_highlightColorIndex % palette.length];
  }

  void _advanceHighlightColor() {
    final palette = HighlightColorPicker.palette;
    if (palette.isEmpty) return;
    _highlightColorIndex = (_highlightColorIndex + 1) % palette.length;
  }

  @override
  void dispose() {
    _cancelUiHideTimer();
    _selectionLostTimer?.cancel();
    if (!_didHandleBack) _provider?.stopReadingTimer();
    _ttsProvider?.removeListener(_onTtsChanged);
    _ttsProvider?.dispose();
    _scrollController.dispose();
    _toolbarCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragStartX == null) return;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (velocity < -500) {
      _lastSwipeDirection = _SwipeDirection.next;
      _provider?.goToNextChapter();
      if (mounted) {
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
      }
      HapticFeedback.lightImpact();
      _scheduleDirectionReset();
      _resetUiHideTimer();
    } else if (velocity > 500) {
      _lastSwipeDirection = _SwipeDirection.previous;
      _provider?.goToPreviousChapter();
      if (mounted) {
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
      }
      HapticFeedback.lightImpact();
      _scheduleDirectionReset();
      _resetUiHideTimer();
    }

    _dragStartX = null;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentOffset = _scrollController.hasClients
          ? _scrollController.offset
          : _lastScrollOffset;
      _provider?.updateScrollPosition(currentOffset);

      // Hide UI chrome while scrolling down, show on scroll up.
      final diff = currentOffset - _lastScrollOffset;
      if (diff > 8 && currentOffset > 80) {
        if (_showUI) {
          setState(() => _showUI = false);
          _hideToolbar();
        }
        _lastScrollOffset = currentOffset;
      } else if (diff < -4 || currentOffset <= 0) {
        if (!_showUI) {
          setState(() => _showUI = true);
          _resetUiHideTimer();
        }
        _applySystemUiMode();
        _lastScrollOffset = currentOffset;
      }
    }
    return false;
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    if (_toolbarVisible) {
      _hideToolbar();
      _resetUiHideTimer();
      return;
    }
    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final screenWidth = renderBox.size.width;

    final provider = _provider!;
    if (provider.chapters.length > 1) {
      if (localPos.dx < screenWidth / 3) {
        _lastSwipeDirection = _SwipeDirection.previous;
        provider.goToPreviousChapter();
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
        _scheduleDirectionReset();
        _resetUiHideTimer();
        return;
      } else if (localPos.dx > 2 * screenWidth / 3) {
        _lastSwipeDirection = _SwipeDirection.next;
        provider.goToNextChapter();
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
        _scheduleDirectionReset();
        _resetUiHideTimer();
        return;
      }
    }
    // Middle tap: force show UI (not toggle).
    _resetUiHideTimer();
  }

  void _showToolbar(Offset origin) {
    // A new selection supersedes any pending dismissal — otherwise the timer
    // armed by the tap that *started* this selection fires a moment later and
    // hides a toolbar the user just summoned.
    _selectionLostTimer?.cancel();
    _selectionLostTimer = null;
    _cancelUiHideTimer();
    setState(() {
      _toolbarVisible = true;
      _selectionOrigin = origin;
    });
    _applySystemUiMode();
    _toolbarCtrl.forward(from: 0);
  }

  /// Dismisses the toolbar once the selection backing it is gone.
  ///
  /// Briefly deferred: dragging a handle or re-selecting emits a transient
  /// cleared/collapsed event immediately before the new selection, and hiding
  /// synchronously would make the toolbar flicker on every adjustment.
  void _hideToolbarOnSelectionLost() {
    if (!_toolbarVisible) return;
    _selectionLostTimer?.cancel();
    _selectionLostTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _selectionLostTimer = null;
      if (_toolbarVisible) _hideToolbar();
    });
  }

  void _hideToolbar() {
    _selectionLostTimer?.cancel();
    _selectionLostTimer = null;
    _toolbarCtrl.reverse();
    setState(() {
      _toolbarVisible = false;
      _colorPickerVisible = false;
    });
    // _selectedText/_selStart are deliberately left alone: the save paths call
    // this before reading them, and they clear their own state when done.
    _applySystemUiMode();
    _resetUiHideTimer();
  }

  /// The paginated + page-curl reading surface.
  ///
  /// Deliberately does not wire the horizontal-drag chapter jump used by scroll
  /// mode: the curl owns horizontal drags, and both competing in the gesture
  /// arena would make page turns unreliable.
  Widget _buildCurlBody(
    ThemeState themeProv,
    ReaderState provider,
    Chapter chapter,
  ) {
    final pad = _horizontalPadding(themeProv.pageWidth);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pad,
        MediaQuery.of(context).padding.top + (_showUI ? 88 : 32),
        pad,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: themeProv.pageWidth),
          child: PaginatedReaderBody(
            chapters: provider.chapters,
            chapterIndex: provider.currentIndex,
            themeProv: themeProv,
            highlights: _highlights,
            highlightVersion: _highlightVersion,
            ttsActive: _ttsProvider?.isActive ?? false,
            ttsStart: _ttsProvider?.currentSentenceOffset ?? 0,
            ttsEnd: _ttsProvider?.currentSentenceEnd ?? 0,
            charOffsetFor: (i) => _provider?.readingOffsetFor(i),
            pixelOffsetFor: (i) => i < provider.chapters.length
                ? provider.chapters[i].scrollPosition
                : 0,
            // Edge taps belong to the curl (it turns pages with them), so a tap
            // reaching us is a middle tap: manage the UI only, never jump
            // chapters the way scroll mode's edge taps do.
            onTap: () {
              if (_toolbarVisible) {
                _hideToolbar();
              }
              _resetUiHideTimer();
            },
            onSelected: (start, end) {
              final text = TextExtractor.extractCached(
                chapter.id,
                chapter.content,
              );
              if (end <= text.length) {
                _selStart = start;
                _selectedText = text.substring(start, end);
                _showToolbar(Offset.zero);
              }
            },
            onSelectionCleared: _hideToolbarOnSelectionLost,
            // A collapsed selection means the handles are gone: the toolbar
            // acts on a selection that no longer exists, so it must go too.
            // Previously this only reset the hide timer, stranding the toolbar
            // until the user tapped it or guessed at empty space.
            onSelectionCollapsed: _hideToolbarOnSelectionLost,
            onChapterChanged: (index) {
              if (index != provider.currentIndex) {
                _provider?.navigateToChapter(index);
              }
            },
            onPositionChanged: (pos, charOffset, {required exact}) {
              _provider?.updateReadingOffset(charOffset);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = ref.watch(themeProvider);
    final provider = ref.watch(readerProvider);
    _onChapterChanged(provider.currentIndex);
    if (provider.loading) {
      return Scaffold(
        backgroundColor: themeProv.isSepia
            ? AppColors.sepiaBg
            : (themeProv.isDark ? AppColors.darkBg : AppColors.lightBg),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.error != null || provider.currentChapter == null) {
      return Scaffold(
        backgroundColor: themeProv.isSepia
            ? AppColors.sepiaBg
            : (themeProv.isDark ? AppColors.darkBg : AppColors.lightBg),
        body: EmptyState(
          icon: AppIcons.alert,
          title: 'Content not available',
          subtitle: provider.error ?? 'This chapter could not be loaded.',
          primaryActionLabel: 'Back to library',
          onPrimaryAction: () => Navigator.pop(context),
        ),
      );
    }

    final book = provider.book!;
    final chapter = provider.currentChapter!;
    final progress = (provider.currentIndex + 1) / provider.chapters.length;
    final readingTime = _estimateReadingTime(chapter.content);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: themeProv.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: themeProv.bgColor,
        bottomNavigationBar: ReaderBottomBar(
          visible: _showUI && !_toolbarVisible,
          onChapters: () =>
              _openChapters(context, ref.read(readerProvider.notifier)),
          onPrevious: () =>
              ref.read(readerProvider.notifier).goToPreviousChapter(),
          onNext: () => ref.read(readerProvider.notifier).goToNextChapter(),
          canGoNext: provider.currentIndex < provider.chapters.length - 1,
          canGoPrevious: provider.currentIndex > 0,
          currentIndex: provider.currentIndex,
          totalChapters: provider.chapters.length,
          readingTimeRemaining: readingTime,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: themeProv.pageStyle == PageStyle.curl
                  ? _buildCurlBody(themeProv, provider, chapter)
                  : GestureDetector(
                      onTapUp: _handleTapUp,
                      onHorizontalDragStart: _onHorizontalDragStart,
                      onHorizontalDragEnd: _onHorizontalDragEnd,
                      behavior: HitTestBehavior.opaque,
                      child: NotificationListener<ScrollStartNotification>(
                        onNotification: (notification) {
                          if (_toolbarVisible) {
                            _hideToolbar();
                            return true;
                          }
                          return false;
                        },
                        child: NotificationListener<ScrollUpdateNotification>(
                          onNotification: _onScrollNotification,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              _horizontalPadding(themeProv.pageWidth),
                              MediaQuery.of(context).padding.top +
                                  (_showUI ? 88 : 32),
                              _horizontalPadding(themeProv.pageWidth),
                              MediaQuery.of(context).padding.bottom + 16,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: themeProv.pageWidth,
                                ),
                                child: ClipRect(
                                  child: AnimatedSwitcher(
                                    duration: AppMotion.sheet,
                                    transitionBuilder: (child, animation) {
                                      var begin = Offset.zero;
                                      switch (_lastSwipeDirection) {
                                        case _SwipeDirection.next:
                                          begin = const Offset(1, 0);
                                        case _SwipeDirection.previous:
                                          begin = const Offset(-1, 0);
                                        case _SwipeDirection.none:
                                          begin = Offset.zero;
                                      }
                                      final slide = Tween(
                                        begin: begin,
                                        end: Offset.zero,
                                      );
                                      final scale = Tween(
                                        begin: 0.96,
                                        end: 1.0,
                                      );
                                      return SlideTransition(
                                        position: animation.drive(slide),
                                        child: ScaleTransition(
                                          scale: animation.drive(scale),
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      key: ValueKey('chapter-${chapter.id}'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Chapter title
                                        Text(
                                          chapter.title,
                                          style:
                                              AppType.reading(
                                                fontSize: themeProv.fontSize,
                                                lineHeight:
                                                    themeProv.lineHeight,
                                                color:
                                                    context.colors.textTertiary,
                                              ).copyWith(
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.1,
                                              ),
                                        ),
                                        const SizedBox(height: 28),
                                        SelectableText.rich(
                                          key: ValueKey(
                                            'content-$_highlightVersion',
                                          ),
                                          TextSpan(
                                            style: _readingStyle(themeProv),
                                            children: _buildReadingSpans(
                                              themeProv,
                                              TextExtractor.extractCached(
                                                chapter.id,
                                                chapter.content,
                                              ),
                                              ttsActive:
                                                  _ttsProvider?.isActive ??
                                                  false,
                                              ttsStart:
                                                  _ttsProvider
                                                      ?.currentSentenceOffset ??
                                                  0,
                                              ttsEnd:
                                                  _ttsProvider
                                                      ?.currentSentenceEnd ??
                                                  0,
                                            ),
                                          ),
                                          textAlign: themeProv.textAlign,
                                          onSelectionChanged: (selection, cause) {
                                            if (selection.isValid &&
                                                !selection.isCollapsed) {
                                              final content =
                                                  TextExtractor.extractCached(
                                                    chapter.id,
                                                    chapter.content,
                                                  );
                                              if (selection.end <=
                                                  content.length) {
                                                // Scroll mode renders the whole chapter,
                                                // so these offsets are already chapter-
                                                // relative.
                                                _selStart = selection.start;
                                                _selectedText = content
                                                    .substring(
                                                      selection.start,
                                                      selection.end,
                                                    );
                                                _showToolbar(Offset.zero);
                                              }
                                            } else {
                                              // Cleared or collapsed: either way the
                                              // selection the toolbar acts on is gone.
                                              _hideToolbarOnSelectionLost();
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 80),
                                      ],
                                    ), // Column
                                  ), // AnimatedSwitcher
                                ), // ClipRect
                              ), // ConstrainedBox
                            ), // Center
                          ), // SingleChildScrollView
                        ), // NotificationListener<ScrollUpdateNotification>
                      ), // NotificationListener<ScrollStartNotification>
                    ), // GestureDetector
            ), // Positioned.fill
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                bookTitle: book.title,
                chapterTitle: chapter.title,
                progress: progress,
                visible: _showUI,
                onBack: () async {
                  _ttsProvider?.stop();
                  if (_provider != null) {
                    await _provider!.stopReadingTimer();
                  }
                  _didHandleBack = true;
                  if (mounted) Navigator.pop(context);
                },
                onSettings: () => ReaderSettingsSheet.show(context),
                onTtsToggle: _toggleTts,
                isTtsActive: _ttsProvider?.isActive ?? false,
              ),
            ),

            // Selection toolbar overlay
            if (_toolbarVisible)
              FadeTransition(
                opacity: _toolbarCtrl,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _toolbarCtrl,
                          curve: AppMotion.standard,
                        ),
                      ),
                  child: Stack(
                    children: [
                      ReaderSelectionToolbar(
                        selectedText: _selectedText ?? '',
                        defaultHighlightColor: _nextHighlightColor,
                        position: _selectionOrigin,
                        onHighlight: (color) {
                          _saveHighlight(color);
                        },
                        onNote: () {
                          _createSnippetFromSelection();
                        },
                        onCopy: () {
                          if (_selectedText != null) {
                            Clipboard.setData(
                              ClipboardData(text: _selectedText!),
                            );
                            StashToast.show(
                              context,
                              message: 'Copied to clipboard',
                              icon: Icons.check,
                            );
                          }
                          _hideToolbar();
                        },
                        onShare: () {
                          if (_selectedText != null) {
                            Clipboard.setData(
                              ClipboardData(text: _selectedText!),
                            );
                            StashToast.show(
                              context,
                              message: 'Quote copied · share anywhere',
                              icon: Icons.ios_share,
                            );
                          }
                          _hideToolbar();
                        },
                      ),
                      if (_colorPickerVisible)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 180,
                          child: Center(
                            child: ScaleTransition(
                              scale: CurvedAnimation(
                                parent: _colorCtrl,
                                curve: AppMotion.standard,
                              ),
                              child: HighlightColorPicker(
                                colors: HighlightColorPicker.palette,
                                selected: _nextHighlightColor,
                                onChanged: (color) {
                                  ref
                                      .read(themeProvider.notifier)
                                      .setDefaultHighlight(color);
                                  final idx = HighlightColorPicker.palette
                                      .indexOf(color);
                                  if (idx >= 0) _highlightColorIndex = idx;
                                  _saveHighlight(color);
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // TTS controls overlay
            if (_ttsProvider != null && _ttsProvider!.isActive)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TtsControls(provider: _ttsProvider!),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleTts() {
    final tts = _ttsProvider;
    if (tts == null) return;
    if (tts.isActive) {
      tts.stop();
      _ttsListening = false;
    } else {
      final text = _currentText;
      if (text.isEmpty) return;
      tts.init(text);
      // ponytail: start from user's rough scroll position
      if (_scrollController.hasClients) {
        final ratio =
            _scrollController.offset /
            _scrollController.position.maxScrollExtent.clamp(
              1,
              double.infinity,
            );
        final idx = (ratio * tts.totalSentences).round().clamp(
          0,
          tts.totalSentences - 1,
        );
        tts.seekToSentence(idx);
      }
      tts.play();
      _ttsListening = true;
    }
  }

  TextStyle _readingStyle(ThemeState themeProv) {
    return ReadingSpans.style(themeProv, context.colors.textPrimary);
  }

  List<TextSpan> _buildReadingSpans(
    ThemeState themeProv,
    String text, {
    bool ttsActive = false,
    int ttsStart = 0,
    int ttsEnd = 0,
  }) {
    return ReadingSpans.build(
      text: text,
      prov: themeProv,
      baseStyle: _readingStyle(themeProv),
      brightness: Theme.of(context).brightness,
      highlights: _highlights,
      ttsActive: ttsActive,
      ttsStart: ttsStart,
      ttsEnd: ttsEnd,
    );
  }

  double _horizontalPadding(double maxWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final leftover = (screenWidth - maxWidth) / 2;
    return leftover < 20 ? 20 : leftover;
  }

  String? _estimateReadingTime(String content) {
    final words = content.split(RegExp(r'\s+')).length;
    final mins = (words / 230).round();
    if (mins < 1) return null;
    return '$mins min left';
  }

  Future<void> _saveHighlight(String color) async {
    final p = _provider!;
    if (_selectedText == null || _selectedText!.trim().isEmpty) return;
    try {
      final repos = ref.watch(repositoriesProvider);
      final ch = p.currentChapter;
      final contentStr = ch != null
          ? TextExtractor.extractCached(ch.id, ch.content)
          : '';
      final selected = _selectedText!.trim();
      int? startOff;
      if (ch != null && selected.isNotEmpty) {
        // Prefer the offsets the layout reported: a bare indexOf finds the
        // *first* occurrence, which is the wrong one whenever the selected
        // phrase repeats in the chapter. Searching forward from the reported
        // start also absorbs the leading whitespace that trim() removed.
        final exact = _selStart;
        final from = (exact != null && exact >= 0 && exact < contentStr.length)
            ? exact
            : 0;
        startOff = contentStr.indexOf(selected, from);
        if (startOff < 0) startOff = contentStr.indexOf(selected);
      }
      // Bug 1 fix: save ONLY to the highlights table, NOT to snippets.
      // Only "Note" (renamed to "Snippet") creates a snippet row.
      if (p.book != null && ch != null && startOff != null && startOff >= 0) {
        // Bound to non-nullable locals: the promotion of startOff/ch does not
        // survive the await below.
        final start = startOff;
        final bookId = p.book!.id;
        final chapterId = ch.id;
        final end = start + selected.length;
        final storedId = await repos.books.insertHighlight(
          Highlight(
            id: 0,
            // No snippetId — marks are separate from snippets
            bookId: bookId,
            chapterId: chapterId,
            startOffset: start,
            endOffset: end,
            color: color,
            text: selected,
          ),
        );
        // Only mutate the in-memory list when we're still viewing the chapter
        // this mark belongs to. Otherwise a mid-await chapter change replaces
        // `_highlights` with another chapter's rows and we'd append here,
        // orphaning the mark until the user navigates back.
        if (mounted && _provider?.currentChapter?.id == chapterId) {
          setState(() {
            if (_highlights.any((h) => h.id == storedId)) return;
            _highlights.add(
              Highlight(
                id: storedId,
                bookId: bookId,
                chapterId: chapterId,
                startOffset: start,
                endOffset: end,
                color: color,
                text: selected,
              ),
            );
          });
        }
      }
      if (mounted) {
        StashToast.show(
          context,
          message: 'Marked',
          icon: Icons.format_color_fill,
        );
      }
    } catch (e) {
      if (mounted) {
        StashToast.show(
          context,
          message: 'Failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      // Cycle to the next highlight color for the next mark.
      _advanceHighlightColor();
      // Discard the old selection so the next long-press can create
      // fresh selection handles.
      // The highlight toolbar just saved — hide it, then increment the
      // SelectableText key so the widget unmounts/remounts cleanly,
      // discarding the old selection state.  Next long-press creates
      // new handles.
      _hideToolbar();
      _selectedText = null;
      _selStart = null;
      setState(() => _highlightVersion++);
      // Dismiss keyboard/selection focus so the next long-press
      // creates a fresh set of selection handles.
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _createSnippetFromSelection() async {
    if (_selectedText == null || _selectedText!.trim().isEmpty) return;
    final p = _provider!;
    final noteCtrl = TextEditingController();
    final themeProv = ref.read(themeProvider);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.brXl,
          side: BorderSide(color: context.colors.border, width: 0.5),
        ),
        title: const Text('Save snippet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.accentMuted,
                borderRadius: AppSpacing.brMd,
              ),
              child: Text(
                _selectedText!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppType.readingItalic(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add your thoughts…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.accent,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _hideToolbar();
    if (saved != true) return;
    try {
      final snippetsProv = ref.read(snippetsProvider.notifier);
      final ch = p.currentChapter;
      final contentStr = ch != null
          ? TextExtractor.extractCached(ch.id, ch.content)
          : '';
      final selected = _selectedText?.trim() ?? '';
      int? startOff;
      if (ch != null && selected.isNotEmpty) {
        // Same reasoning as _saveHighlight: search forward from the offset the
        // layout reported so a repeated phrase resolves to the copy the reader
        // actually selected.
        final exact = _selStart;
        final from = (exact != null && exact >= 0 && exact < contentStr.length)
            ? exact
            : 0;
        startOff = contentStr.indexOf(selected, from);
        if (startOff < 0) startOff = contentStr.indexOf(selected);
      }
      final currPos = _scrollController.hasClients
          ? _scrollController.offset
          : null;
      await snippetsProv.createSnippet(
        text: selected,
        note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
        color: themeProv.defaultHighlight,
        sourceTitle: p.book?.title,
        sourceUrl: p.book?.sourceUrl,
        bookId: p.book?.id,
        chapterId: p.currentChapter?.id,
        scrollPosition: currPos,
        startOffset: startOff != null && startOff >= 0 ? startOff : null,
        endOffset: startOff != null && startOff >= 0
            ? startOff + selected.length
            : null,
      );
      if (mounted) {
        StashToast.show(
          context,
          message: 'Snippet saved',
          icon: Icons.bookmark_add,
        );
      }
    } catch (e) {
      if (mounted) {
        StashToast.show(
          context,
          message: 'Failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      _selectedText = null;
      _selStart = null;
    }
  }

  void _openChapters(BuildContext context, ReaderNotifier provider) {
    if (provider.chapters.length <= 1) return;
    ChapterNavOverlay.show(
      context,
      chapters: provider.chapters,
      currentIndex: provider.currentIndex,
      onSelect: (i) {
        provider.navigateToChapter(i);
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
      },
      onPrevious: () => provider.goToPreviousChapter(),
      onNext: () => provider.goToNextChapter(),
    );
  }
}
