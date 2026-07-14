import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/services/database_service.dart';
import '../../core/services/stats_service.dart';

class ReaderProvider extends ChangeNotifier {
  final DatabaseService _db;
  final StatsService _statsService;

  Book? _book;
  List<Chapter> _chapters = [];
  Chapter? _currentChapter;
  int _currentIndex = 0;
  double _scrollPosition = 0.0;
  bool _loading = true;
  String? _error;

  /// Per-chapter scroll position. Keyed by chapter index. Populated
  /// from the DB on load and updated as the user scrolls.
  final Map<int, double> _chapterScrollPositions = {};

  Timer? _readingTimer;
  int _elapsedSeconds = 0;
  Timer? _scrollPersistTimer;
  double? _pendingScroll;

  ReaderProvider(this._db, this._statsService);

  Book? get book => _book;
  List<Chapter> get chapters => _chapters;
  Chapter? get currentChapter => _currentChapter;
  int get currentIndex => _currentIndex;
  double get scrollPosition => _scrollPosition;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadBook(int bookId) async {
    _loading = true;
    _error = null;
    _elapsedSeconds = 0;
    notifyListeners();

    try {
      _book = await _db.getBook(bookId);
      _chapters = await _db.getChapters(bookId);

      if (_book != null && _chapters.isNotEmpty) {
        _currentIndex =
            _book!.currentChapterIndex.clamp(0, _chapters.length - 1);
        _currentChapter = _chapters[_currentIndex];
        // Populate the per-chapter scroll map from the DB. This makes
        // back-navigation restore exactly where the user left off.
        for (var i = 0; i < _chapters.length; i++) {
          _chapterScrollPositions[i] = _chapters[i].scrollPosition;
        }
        // The book-level scroll is only used as a fallback when the
        // current chapter's per-chapter position is 0.
        final chPos = _chapterScrollPositions[_currentIndex] ?? 0.0;
        _scrollPosition = chPos > 0 ? chPos : _book!.scrollPosition;
        await _db.markChapterRead(_currentChapter!.id);
      }

      _startReadingTimer();
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  void navigateToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    // Persist the outgoing chapter's pending scroll before leaving.
    _flushPendingScroll();
    _currentIndex = index;
    _currentChapter = _chapters[index];
    _scrollPosition = _chapterScrollPositions[index] ?? 0.0;
    _db.markChapterRead(_currentChapter!.id);
    _updateBookProgress();
    notifyListeners();
  }

  void goToNextChapter() {
    if (_currentIndex < _chapters.length - 1) {
      navigateToChapter(_currentIndex + 1);
    }
  }

  void goToPreviousChapter() {
    if (_currentIndex > 0) {
      navigateToChapter(_currentIndex - 1);
    }
  }

  void updateScrollPosition(double position) {
    _scrollPosition = position;
    _chapterScrollPositions[_currentIndex] = position;
    // Debounce the DB write — scrolling fires hundreds of events per
    // second; we only need to persist the latest position once the
    // user pauses.
    _pendingScroll = position;
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = Timer(const Duration(milliseconds: 1500), () {
      _flushPendingScroll();
    });
  }

  void _flushPendingScroll() {
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = null;
    final pos = _pendingScroll;
    final ch = _currentChapter;
    if (pos == null || ch == null) return;
    _pendingScroll = null;
    _db.updateChapterScroll(ch.id, pos);
  }

  void _updateBookProgress() {
    if (_book == null || _chapters.isEmpty) return;
    final progress = (_currentIndex + 1) / _chapters.length;
    _book = _book!.copyWith(
      progress: progress,
      currentChapterIndex: _currentIndex,
      scrollPosition: _scrollPosition,
    );
    _db.updateProgress(
      _book!.id,
      progress,
      currentChapterIndex: _currentIndex,
      scrollPosition: _scrollPosition,
    );
  }

  void _startReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _elapsedSeconds += 30;
      _statsService.trackReading(_book?.id ?? 0, 30);
    });
  }

  void stopReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
    if (_elapsedSeconds > 0) {
      _statsService.trackReading(_book?.id ?? 0, _elapsedSeconds % 30);
    }
    // Persist the most recent scroll position before tearing down.
    _flushPendingScroll();
    // Mark book as complete if at last chapter
    if (_book != null &&
        _currentIndex == _chapters.length - 1 &&
        _book!.progress < 1.0) {
      _book = _book!.copyWith(
          progress: 1.0, scrollPosition: _scrollPosition);
      _db.updateProgress(_book!.id, 1.0,
          scrollPosition: _scrollPosition);
      _statsService.trackCompletion(_book!.id);
    }
    _updateBookProgress();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _scrollPersistTimer?.cancel();
    _flushPendingScroll();
    super.dispose();
  }
}
