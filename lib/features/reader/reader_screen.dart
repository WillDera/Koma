import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../features/snippets/snippets_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/bionic_text.dart';
import '../../widgets/chapter_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/highlight_color_picker.dart';
import '../../widgets/reader_bottom_bar.dart';
import '../../widgets/reader_settings_sheet.dart';
import '../../widgets/reader_top_bar.dart';
import '../../widgets/text_selection_toolbar.dart';
import '../../widgets/toast.dart';
import '../../core/utils/text_extractor.dart';
import 'reader_provider.dart';

class ReaderScreen extends StatefulWidget {
  final int bookId;
  const ReaderScreen({super.key, required this.bookId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  ReaderProvider? _provider;

  String? _selectedText;
  bool _showUI = true;
  bool _toolbarVisible = false;
  bool _colorPickerVisible = false;
  double _lastScrollOffset = 0;
  Offset _selectionOrigin = Offset.zero;

  /// Index of the chapter we're currently showing. Used to detect a
  /// chapter change after navigation so we can jump the scroll back
  /// to the saved (or 0) position.
  int _lastSeenChapterIndex = -1;

  late final AnimationController _toolbarCtrl;
  late final AnimationController _colorCtrl;

  @override
  void initState() {
    super.initState();
    _toolbarCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.sheet,
    );
    _colorCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.base,
    );
    Future.microtask(() => _loadAndRestore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= context.read<ReaderProvider>();
  }

  Future<void> _loadAndRestore() async {
    await _provider!.loadBook(widget.bookId);
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
              pos.clamp(0, _scrollController.position.maxScrollExtent));
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _provider?.scrollPosition ?? 0;
      _scrollController.jumpTo(
          pos.clamp(0, _scrollController.position.maxScrollExtent));
    });
  }

  bool _didHandleBack = false;

  @override
  void dispose() {
    if (!_didHandleBack) _provider?.stopReadingTimer();
    _scrollController.dispose();
    _toolbarCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
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
        if (!_showUI) setState(() => _showUI = true);
        _lastScrollOffset = currentOffset;
      }
    }
    return false;
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    if (_toolbarVisible) {
      _hideToolbar();
      return;
    }
    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final screenWidth = renderBox.size.width;

    final provider = _provider!;
    if (provider.chapters.length > 1) {
      if (localPos.dx < screenWidth / 3) {
        provider.goToPreviousChapter();
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
        return;
      } else if (localPos.dx > 2 * screenWidth / 3) {
        provider.goToNextChapter();
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
        return;
      }
    }
    setState(() => _showUI = !_showUI);
  }

  void _showToolbar(Offset origin) {
    setState(() {
      _toolbarVisible = true;
      _selectionOrigin = origin;
    });
    _toolbarCtrl.forward(from: 0);
  }

  void _hideToolbar() {
    _toolbarCtrl.reverse();
    setState(() {
      _toolbarVisible = false;
      _colorPickerVisible = false;
    });
  }

  void _showColorPicker() {
    setState(() => _colorPickerVisible = true);
    _colorCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    return Consumer<ReaderProvider>(
      builder: (context, provider, _) {
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
              icon: Icons.error_outline,
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
              onChapters: () => _openChapters(context, provider),
              onPrevious: provider.goToPreviousChapter,
              onNext: provider.goToNextChapter,
              canGoNext:
                  provider.currentIndex < provider.chapters.length - 1,
              canGoPrevious: provider.currentIndex > 0,
              currentIndex: provider.currentIndex,
              totalChapters: provider.chapters.length,
              readingTimeRemaining: readingTime,
            ),
            body: Stack(
              children: [
                GestureDetector(
                  onTapUp: _handleTapUp,
                  behavior: HitTestBehavior.opaque,
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: (notification) {
                      // When the user starts scrolling while the selection
                      // toolbar is visible, dismiss it and absorb the
                      // scroll-start notification so ScrollNotificationObserver
                      // never tries to query the now-stale text selection
                      // (assertion: selection.isValid).
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
                        MediaQuery.of(context).padding.top + (_showUI ? 88 : 32),
                        _horizontalPadding(themeProv.pageWidth),
                        MediaQuery.of(context).padding.bottom + 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: themeProv.pageWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chapter title
                              Text(
                                chapter.title,
                                style: AppType.reading(
                                  fontSize: themeProv.fontSize,
                                  lineHeight: themeProv.lineHeight,
                                  color: context.colors.textTertiary,
                                ).copyWith(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SelectableText.rich(
                                TextSpan(
                                  style: _readingStyle(themeProv),
                                  children: _buildReadingSpans(
                                    themeProv,
                                    TextExtractor.extractFromHtml(chapter.content),
                                  ),
                                ),
                                textAlign: themeProv.textAlign,
                                onSelectionChanged: (selection, cause) {
                                  if (selection.isValid &&
                                      !selection.isCollapsed) {
                                    final content =
                                        TextExtractor.extractFromHtml(chapter.content);
                                    if (selection.end <= content.length) {
                                      _selectedText = content.substring(
                                          selection.start, selection.end);
                                      _showToolbar(Offset.zero);
                                    }
                                  } else if (_toolbarVisible) {
                                    // Delay to allow taps on toolbar items.
                                    Future.delayed(
                                      const Duration(milliseconds: 200),
                                      () {
                                        if (!mounted) return;
                                        if (_toolbarVisible) _hideToolbar();
                                      },
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),                        // Column
                        ),                          // ConstrainedBox
                      ),                            // Center
                    ),                              // SingleChildScrollView
                  ),                                // NotificationListener<ScrollUpdateNotification>
                ),                                  // NotificationListener<ScrollStartNotification>
              ),                                    // GestureDetector

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
                      if (_provider != null) {
                        await _provider!.stopReadingTimer();
                      }
                      _didHandleBack = true;
                      if (mounted) Navigator.pop(context);
                    },
                    onSettings: () =>
                        ReaderSettingsSheet.show(context, themeProv),
                  ),
                ),

                // Selection toolbar overlay
                if (_toolbarVisible)
                  FadeTransition(
                    opacity: _toolbarCtrl,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: _toolbarCtrl, curve: AppMotion.standard)),
                      child: Stack(
                        children: [
                          ReaderSelectionToolbar(
                            selectedText: _selectedText ?? '',
                            defaultHighlightColor: themeProv.defaultHighlight,
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
                                    ClipboardData(text: _selectedText!));
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
                                    ClipboardData(text: _selectedText!));
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
                                    selected: themeProv.defaultHighlight,
                                    onChanged: (color) {
                                      themeProv.setDefaultHighlight(color);
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
              ],
            ),
          ),
        );
      },
    );
  }

  TextStyle _readingStyle(ThemeProvider themeProv) {
    final c = context.colors;
    return AppType.fontStyle(
      fontFamily: themeProv.readingFontFamily,
      fontSize: themeProv.fontSize,
      lineHeight: themeProv.lineHeight,
      color: c.textPrimary,
    );
  }

  List<TextSpan> _buildReadingSpans(ThemeProvider themeProv, String text) {
    final style = _readingStyle(themeProv);
    if (themeProv.bionicReading) {
      return BionicText.spans(
        text,
        baseStyle: style,
        bionicWeight: themeProv.bionicBoldWeight,
        bionicFraction: themeProv.bionicBoldFraction,
      );
    }
    return [TextSpan(text: text, style: style)];
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
    if (!_colorPickerVisible) {
      _showColorPicker();
      return;
    }
    try {
      final snippetsProvider = context.read<SnippetsProvider>();
      await snippetsProvider.createSnippet(
        text: _selectedText!.trim(),
        color: color,
        sourceTitle: p.book?.title,
        sourceUrl: p.book?.sourceUrl,
        bookId: p.book?.id,
        chapterId: p.currentChapter?.id,
        tags: const ['highlight'],
      );
      if (mounted) {
        StashToast.show(
          context,
          message: 'Highlighted',
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
      _hideToolbar();
    }
  }

  Future<void> _createSnippetFromSelection() async {
    if (_selectedText == null || _selectedText!.trim().isEmpty) return;
    final p = _provider!;
    final noteCtrl = TextEditingController();
    final themeProv = context.read<ThemeProvider>();
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
      final snippetsProvider = context.read<SnippetsProvider>();
      await snippetsProvider.createSnippet(
        text: _selectedText!.trim(),
        note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
        color: themeProv.defaultHighlight,
        sourceTitle: p.book?.title,
        sourceUrl: p.book?.sourceUrl,
        bookId: p.book?.id,
        chapterId: p.currentChapter?.id,
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
    }
  }

  void _openChapters(BuildContext context, ReaderProvider provider) {
    if (provider.chapters.length <= 1) return;
    ChapterSheet.show(
      context,
      bookTitle: provider.book?.title ?? '',
      chapters: provider.chapters,
      currentIndex: provider.currentIndex,
      onSelect: (i) {
        provider.navigateToChapter(i);
        setState(() {
          _lastScrollOffset = 0;
          _showUI = true;
        });
      },
    );
  }

}
