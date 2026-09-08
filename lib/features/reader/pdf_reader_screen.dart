import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/services/storage_path_rewrite.dart';
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

    const appBarBg = Color(0xFF0F0F0F);
    AppBar pdfAppBar({Widget? title}) => AppBar(
          backgroundColor: appBarBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: c.textPrimary,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: title,
        );

    return bookAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: pdfAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: pdfAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is _PdfMissingFileException
                  ? e.message
                  : 'Could not open PDF: $e',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
        ),
      ),
      data: (opened) {
        final book = opened.book;
        final path = opened.resolvedPath;
        final initialPage =
            (widget.initialPage ?? book.currentChapterIndex).clamp(
          0,
          book.totalChapters > 0 ? book.totalChapters - 1 : 0,
        );
        _pageCount = book.totalChapters;

        return Scaffold(
          backgroundColor: c.bg,
          resizeToAvoidBottomInset: false,
          appBar: pdfAppBar(
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
              errorBannerBuilder: (context, error, stackTrace, documentRef) {
                return _PdfLoadError(message: _friendlyPdfError(error));
              },
            ),
          ),
        );
      },
    );
  }
}

String _friendlyPdfError(Object error) {
  final text = error.toString();
  if (text.contains('FPDF_ERR_FILE') || text.contains('ERR_FILE')) {
    return 'PDF file is missing or unreadable. Re-import the book, or check '
        'that your data folder still contains the downloads.';
  }
  if (text.contains('FPDF_ERR_PASSWORD') || text.contains('password')) {
    return 'This PDF is password-protected and cannot be opened yet.';
  }
  return 'Could not open this PDF.\n$text';
}

class _PdfLoadError extends StatelessWidget {
  const _PdfLoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _PdfOpenedBook {
  const _PdfOpenedBook({required this.book, required this.resolvedPath});

  final Book book;
  final String resolvedPath;
}

class _PdfMissingFileException implements Exception {
  _PdfMissingFileException(this.message);
  final String message;

  @override
  String toString() => message;
}

final _pdfBookProvider =
    FutureProvider.autoDispose.family<_PdfOpenedBook, int>((ref, bookId) async {
  final repos = ref.read(repositoriesProvider);
  final book = await repos.books.getBook(bookId);
  if (book == null) throw StateError('Book $bookId not found');

  final stored = book.filePath?.trim() ?? '';
  if (stored.isEmpty) {
    throw _PdfMissingFileException('PDF file path missing');
  }

  var path = stored;
  if (!await File(path).exists()) {
    final remapped = await StoragePathRewrite.remapIfMissing(path);
    if (remapped == null) {
      throw _PdfMissingFileException(
        'PDF file is missing on disk. Re-import the book from Files, or check '
        'your data folder.',
      );
    }
    path = remapped;
    if (path != stored) {
      await repos.books.updateBook(book.copyWith(filePath: path));
    }
  }

  return _PdfOpenedBook(book: book, resolvedPath: path);
});
