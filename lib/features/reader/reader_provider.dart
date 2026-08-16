import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/providers.dart';
import '../../core/services/koma_package_store.dart';
import '../../features/reader/html/kir_model.dart';

/// Immutable state for the ebook reader.
class ReaderState {
  const ReaderState({
    this.book,
    this.chapters = const [],
    this.currentChapter,
    this.currentIndex = 0,
    this.scrollPosition = 0.0,
    this.loading = true,
    this.error,
    this.currentKir,
  });

  final Book? book;
  final List<Chapter> chapters;
  final Chapter? currentChapter;
  final int currentIndex;
  final double scrollPosition;
  final bool loading;
  final String? error;

  /// KIR for [currentChapter] when a `.koma` exists and spine count matches.
  final KirChapter? currentKir;

  ReaderState copyWith({
    Book? Function()? book,
    List<Chapter>? chapters,
    Chapter? Function()? currentChapter,
    int? currentIndex,
    double? scrollPosition,
    bool? loading,
    String? Function()? error,
    KirChapter? Function()? currentKir,
  }) {
    return ReaderState(
      book: book != null ? book() : this.book,
      chapters: chapters ?? this.chapters,
      currentChapter: currentChapter != null
          ? currentChapter()
          : this.currentChapter,
      currentIndex: currentIndex ?? this.currentIndex,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
      currentKir: currentKir != null ? currentKir() : this.currentKir,
    );
  }
}

class ReaderNotifier extends Notifier<ReaderState> {
  final Map<int, double> _chapterScrollPositions = {};
  Timer? _readingTimer;
  int _elapsedSeconds = 0;
  Timer? _scrollPersistTimer;
  ({int chapterId, double position})? _pendingScroll;

  /// Reading position per chapter index, as a character offset. Populated from
  /// storage on load and updated as paginated mode turns pages.
  final Map<int, int> _chapterReadingOffsets = {};
  Timer? _offsetPersistTimer;
  int? _pendingOffset;

  final Map<int, KirChapter> _kirByIndex = {};
  bool _kirEnabled = false;
  int? _kirBookId;

  @override
  ReaderState build() => const ReaderState();

  // Convenience accessors — avoids verbose `.state.` in consumer code
  // that holds a direct reference to the notifier.
  Book? get book => state.book;
  List<Chapter> get chapters => state.chapters;
  Chapter? get currentChapter => state.currentChapter;
  int get currentIndex => state.currentIndex;
  KirChapter? get currentKir => state.currentKir;
  double get scrollPosition =>
      _chapterScrollPositions[state.currentIndex] ?? state.scrollPosition;
  bool get loading => state.loading;
  String? get error => state.error;

  Future<void> loadBook(
    int bookId, {
    int? targetChapterId,
    double? targetScrollOffset,
  }) async {
    _elapsedSeconds = 0;
    _kirByIndex.clear();
    _kirEnabled = false;
    _kirBookId = null;
    state = state.copyWith(loading: true, error: () => null);
    final repos = ref.watch(repositoriesProvider);

    try {
      final book = await repos.books.getBook(bookId);
      final chapters = await repos.books.getChapters(bookId);

      if (book != null && chapters.isNotEmpty) {
        var currentIndex = book.currentChapterIndex.clamp(
          0,
          chapters.length - 1,
        );
        if (targetChapterId != null) {
          final idx = chapters.indexWhere((ch) => ch.id == targetChapterId);
          if (idx >= 0) currentIndex = idx;
        }
        final currentChapter = chapters[currentIndex];
        _chapterScrollPositions.clear();
        _chapterReadingOffsets.clear();
        for (var i = 0; i < chapters.length; i++) {
          _chapterScrollPositions[i] = chapters[i].scrollPosition;
          final off = chapters[i].readingCharOffset;
          if (off != null) _chapterReadingOffsets[i] = off;
        }
        final chPos = _chapterScrollPositions[currentIndex] ?? 0.0;
        final scrollPos =
            targetScrollOffset ?? (chPos > 0 ? chPos : book.scrollPosition);

        await _prepareKir(book.id, chapters.length);
        final kir = await _kirFor(currentIndex);

        state = ReaderState(
          book: book,
          chapters: chapters,
          currentChapter: currentChapter,
          currentIndex: currentIndex,
          scrollPosition: scrollPos,
          loading: false,
          currentKir: kir,
        );
        await repos.books.markChapterRead(currentChapter.id);
        _startReadingTimer();
        _prefetchKirNeighbours(currentIndex, chapters.length);
      } else {
        state = state.copyWith(
          book: () => book,
          chapters: chapters,
          loading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), loading: false);
    }
  }

  void navigateToChapter(int index) {
    if (index < 0 || index >= state.chapters.length) return;
    // Both flushes must happen while currentChapter is still the outgoing one,
    // otherwise the pending position is written against the wrong chapter.
    _flushPendingScroll();
    _flushPendingOffset();
    final chapter = state.chapters[index];
    final scrollPos = _chapterScrollPositions[index] ?? 0.0;
    state = state.copyWith(
      currentIndex: index,
      currentChapter: () => chapter,
      scrollPosition: scrollPos,
      currentKir: () => _kirByIndex[index],
    );
    final repos = ref.read(repositoriesProvider);
    repos.books.markChapterRead(chapter.id);
    _updateBookProgress();
    _prefetchKirNeighbours(index, state.chapters.length);
  }

  void goToNextChapter() {
    if (state.currentIndex < state.chapters.length - 1) {
      navigateToChapter(state.currentIndex + 1);
    }
  }

  void goToPreviousChapter() {
    if (state.currentIndex > 0) {
      navigateToChapter(state.currentIndex - 1);
    }
  }

  void updateScrollPosition(double position) {
    _chapterScrollPositions[state.currentIndex] = position;
    final chapter = state.currentChapter;
    if (chapter == null) return;
    _pendingScroll = (chapterId: chapter.id, position: position);
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = Timer(const Duration(milliseconds: 1500), () {
      _flushPendingScroll();
    });
  }

  Future<void> _flushPendingScroll() async {
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = null;
    final pending = _pendingScroll;
    if (pending == null) return;
    _pendingScroll = null;
    final repos = ref.read(repositoriesProvider);
    await repos.books.updateChapterScroll(pending.chapterId, pending.position);
  }

  /// The stored character offset for a chapter, or null if none was recorded.
  int? readingOffsetFor(int chapterIndex) =>
      _chapterReadingOffsets[chapterIndex];

  /// Records the paginated reading position, debounced like scroll.
  ///
  /// Page turns are far less frequent than scroll ticks, but a fast flick
  /// through several pages still shouldn't mean a write per page.
  void updateReadingOffset(int charOffset) {
    _chapterReadingOffsets[state.currentIndex] = charOffset;
    _pendingOffset = charOffset;
    _offsetPersistTimer?.cancel();
    _offsetPersistTimer = Timer(const Duration(milliseconds: 1500), () {
      _flushPendingOffset();
    });
  }

  Future<void> _flushPendingOffset() async {
    _offsetPersistTimer?.cancel();
    _offsetPersistTimer = null;
    final off = _pendingOffset;
    final ch = state.currentChapter;
    if (off == null || ch == null) return;
    _pendingOffset = null;
    final repos = ref.watch(repositoriesProvider);
    await repos.books.updateChapterReadingOffset(ch.id, off);
  }

  Future<void> _updateBookProgress() async {
    final book = state.book;
    if (book == null || state.chapters.isEmpty) return;
    final progress = (state.currentIndex + 1) / state.chapters.length;
    final updatedBook = book.copyWith(
      progress: progress,
      currentChapterIndex: state.currentIndex,
      scrollPosition: scrollPosition,
    );
    state = state.copyWith(book: () => updatedBook);
    final repos = ref.read(repositoriesProvider);
    await repos.books.updateProgress(
      book.id,
      progress,
      currentChapterIndex: state.currentIndex,
      scrollPosition: scrollPosition,
    );
    // Bump the history revision so the History tab refreshes in real time.
    ref.read(historyRevisionProvider.notifier).bump();
  }

  void _startReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _elapsedSeconds += 30;
      ref.read(statsServiceProvider).trackReading(state.book?.id ?? 0, 30);
    });
  }

  Future<void> stopReadingTimer() async {
    _readingTimer?.cancel();
    _readingTimer = null;
    final stats = ref.read(statsServiceProvider);
    if (_elapsedSeconds > 0) {
      stats.trackReading(state.book?.id ?? 0, _elapsedSeconds % 30);
    }
    await _flushPendingScroll();
    await _flushPendingOffset();
    final book = state.book;
    if (book != null &&
        state.currentIndex == state.chapters.length - 1 &&
        book.progress < 1.0) {
      final updated = book.copyWith(
        progress: 1.0,
        scrollPosition: scrollPosition,
      );
      state = state.copyWith(book: () => updated);
      final repos = ref.read(repositoriesProvider);
      await repos.books.updateProgress(
        book.id,
        1.0,
        scrollPosition: scrollPosition,
      );
      stats.trackCompletion(book.id);
    }
    await _updateBookProgress();
  }

  Future<void> _prepareKir(int bookId, int chapterCount) async {
    _kirByIndex.clear();
    _kirEnabled = false;
    _kirBookId = bookId;
    final count = await KomaPackageStore.chapterCount(bookId);
    if (count == null || count != chapterCount) return;
    _kirEnabled = true;
  }

  Future<KirChapter?> _kirFor(int index) async {
    if (!_kirEnabled || _kirBookId == null) return null;
    final hit = _kirByIndex[index];
    if (hit != null) return hit;
    final chapter = await KomaPackageStore.chapterByIndex(
      bookId: _kirBookId!,
      index: index,
    );
    if (chapter != null) _kirByIndex[index] = chapter;
    return chapter;
  }

  void _prefetchKirNeighbours(int index, int length) {
    if (!_kirEnabled) return;
    for (final i in {index - 1, index + 1}) {
      if (i < 0 || i >= length || _kirByIndex.containsKey(i)) continue;
      unawaited(_kirFor(i));
    }
  }
}
