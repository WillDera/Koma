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
    _pendingScroll = position;
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = Timer(const Duration(milliseconds: 1500), () {
      _flushPendingScroll();
    });
  }

  /// Flush the pending scroll position to the DB and return when done.
  Future<void> _flushPendingScroll() async {
    _scrollPersistTimer?.cancel();
    _scrollPersistTimer = null;
    final pos = _pendingScroll;
    final ch = _currentChapter;
    if (pos == null || ch == null) return;
    _pendingScroll = null;
    await _db.updateChapterScroll(ch.id, pos);
  }

  /// Update the book's progress / position in the DB.
  /// Returns once the write is committed.
  Future<void> _updateBookProgress() async {
    if (_book == null || _chapters.isEmpty) return;
    final progress = (_currentIndex + 1) / _chapters.length;
    _book = _book!.copyWith(
      progress: progress,
      currentChapterIndex: _currentIndex,
      scrollPosition: _scrollPosition,
    );
    await _db.updateProgress(
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

  /// Flush pending scroll position and stop the reading timer.
  /// The caller should await this before navigating away so the DB
  /// write completes before the next screen reads the data.
  Future<void> stopReadingTimer() async {
    _readingTimer?.cancel();
    _readingTimer = null;
    if (_elapsedSeconds > 0) {
      _statsService.trackReading(_book?.id ?? 0, _elapsedSeconds % 30);
    }
    await _flushPendingScroll();
    if (_book != null &&
        _currentIndex == _chapters.length - 1 &&
        _book!.progress < 1.0) {
      _book = _book!.copyWith(
          progress: 1.0, scrollPosition: _scrollPosition);
      await _db.updateProgress(_book!.id, 1.0,
          scrollPosition: _scrollPosition);
      _statsService.trackCompletion(_book!.id);
    }
    // Update book progress & scroll position — this is what the
    // history screen reads.  Await it so the data is in the DB
    // before the .then() fires on the calling screen.
    _updateBookProgress();
    // _updateBookProgress fires async DB writes.  Wait for the DB
    // queue to drain before returning.
    await _db.db.customSelect('SELECT 1');
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _scrollPersistTimer?.cancel();
    _flushPendingScroll();
    super.dispose();
  }
}
