import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import 'epub_service.dart';

/// Imports a PDF as a single-document library book (page index = progress).
class PdfService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final doc = await PdfDocument.openFile(filePath);
      try {
        final pageCount = doc.pages.length;
        if (pageCount == 0) return null;

        final fileName = p.basenameWithoutExtension(filePath);
        final title = _titleFromMetadata(doc) ?? fileName;

        final book = Book(
          id: bookId ?? 0,
          title: title,
          source: 'local',
          filePath: filePath,
          fileExtension: 'pdf',
          totalChapters: pageCount,
        );

        return EpubResult(book: book, chapters: const []);
      } finally {
        await doc.dispose();
      }
    } catch (e) {
      throw Exception('Failed to parse PDF: $e');
    }
  }

  String? _titleFromMetadata(PdfDocument doc) {
    try {
      final title = doc.sourceName;
      if (title.isNotEmpty && !title.endsWith('.pdf')) {
        return title;
      }
    } catch (_) {}
    return null;
  }
}
