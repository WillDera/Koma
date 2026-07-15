import 'dart:io';
import '../models/book.dart';
import '../models/chapter.dart';
import 'epub_service.dart';

class TxtService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    try {
      final text = await File(filePath).readAsString();
      final title = filePath.split('/').last.replaceAll(RegExp(r'\.txt$'), '');
      final bookIdFinal = bookId ?? 0;

      final sections = text.split(RegExp(r'\n\s*\n'));
      final chapters = <Chapter>[];
      for (var i = 0; i < sections.length; i++) {
        final lines = sections[i].trim().split('\n');
        String chTitle;
        String content;
        if (lines.length > 1) {
          chTitle = lines.first.trim();
          content = lines.sublist(1).join('\n').trim();
        } else {
          chTitle = 'Part ${i + 1}';
          content = lines.first.trim();
        }
        chapters.add(Chapter(
          id: 0,
          bookId: bookIdFinal,
          title: chTitle.isEmpty ? 'Chapter ${i + 1}' : chTitle,
          content: '<p>${_escapeHtml(content)}</p>',
          index: i,
        ));
      }

      if (chapters.isEmpty) {
        chapters.add(Chapter(
          id: 0,
          bookId: bookIdFinal,
          title: title,
          content: '<p>${_escapeHtml(text)}</p>',
          index: 0,
        ));
      }

      final book = Book(
        id: bookIdFinal,
        title: title,
        source: 'local',
        filePath: filePath,
        totalChapters: chapters.length,
      );

      return EpubResult(book: book, chapters: chapters);
    } catch (e) {
      throw Exception('Failed to parse TXT: $e');
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
