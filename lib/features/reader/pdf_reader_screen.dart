import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

/// Read-only PDF viewer for library books ([Book.fileExtension] == pdf).
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.bookId, this.initialPage});

  final int bookId;
  final int? initialPage;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  Timer? _saveDebounce;
  int _pageCount = 0;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _scheduleSave(int pageIndex) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistPage(pageIndex));
    });
  }

  Future<void> _persistPage(int pageIndex) async {
    if (_pageCount <= 0) return;
    final repos = ref.read(repositoriesProvider);
    final progress = ((pageIndex + 1) / _pageCount).clamp(0.0, 1.0);
    await repos.books.updateProgress(
      widget.bookId,
      progress,
      currentChapterIndex: pageIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bookAsync = ref.watch(_pdfBookProvider(widget.bookId));

    return bookAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: Center(
          child: Text('Could not open PDF: $e', style: TextStyle(color: c.textSecondary)),
        ),
      ),
      data: (book) {
        final path = book.filePath;
        if (path == null || path.isEmpty) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(backgroundColor: c.bg),
            body: Center(
              child: Text(
                'PDF file path missing',
                style: TextStyle(color: c.textSecondary),
              ),
            ),
          );
        }

        final initialPage = (widget.initialPage ?? book.currentChapterIndex).clamp(
          0,
          book.totalChapters > 0 ? book.totalChapters - 1 : 0,
        );
        _pageCount = book.totalChapters;

        return Scaffold(
          backgroundColor: c.bg,
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: c.bg,
            iconTheme: IconThemeData(color: c.textPrimary),
            title: Text(
              book.title,
              style: TextStyle(color: c.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: PdfViewer.file(
            path,
            initialPageNumber: initialPage + 1,
            params: PdfViewerParams(
              onPageChanged: (page) {
                if (page == null) return;
                _scheduleSave(page - 1);
              },
            ),
          ),
        );
      },
    );
  }
}

final _pdfBookProvider = FutureProvider.autoDispose.family<Book, int>(
  (ref, bookId) async {
    final repos = ref.read(repositoriesProvider);
    final book = await repos.books.getBook(bookId);
    if (book == null) throw StateError('Book $bookId not found');
    return book;
  },
);
