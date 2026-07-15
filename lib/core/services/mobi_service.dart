import 'dart:io';
import 'package:kindle_unpack/kindle_unpack.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'epub_service.dart';

class MobiService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final book = KindleBook.fromBytes(bytes);
      final bookIdFinal = bookId ?? 0;

      // Save cover image
      String? coverPath;
      final coverImg = book.images.cover;
      if (coverImg != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final coverDir = Directory('${appDir.path}/covers');
          if (!await coverDir.exists()) await coverDir.create(recursive: true);
          final outFile = File(
              '${coverDir.path}/${DateTime.now().millisecondsSinceEpoch}.${coverImg.format.extension}');
          await outFile.writeAsBytes(coverImg.data);
          coverPath = outFile.path;
        } catch (_) {}
      }

      // Author
      String? author;
      try {
        final exth = book.exth;
        if (exth != null && exth.authors.isNotEmpty) {
          author = exth.authors.join(', ');
        }
      } catch (_) {}

      // Chapters from parts
      final chapters = <Chapter>[];
      if (book.parts.isNotEmpty) {
        for (var i = 0; i < book.parts.length; i++) {
          final part = book.parts[i];
          final html = String.fromCharCodes(part.bytes);
          final chTitle = _extractTitle(html) ?? 'Chapter ${i + 1}';
          chapters.add(Chapter(
            id: 0,
            bookId: bookIdFinal,
            title: chTitle,
            content: html,
            index: i,
          ));
        }
      } else {
        // Fallback to rawML
        final text = String.fromCharCodes(book.rawML);
        chapters.add(Chapter(
          id: 0,
          bookId: bookIdFinal,
          title: book.title,
          content: text,
          index: 0,
        ));
      }

      final ebook = Book(
        id: bookIdFinal,
        title: book.title,
        author: author,
        coverPath: coverPath,
        source: 'local',
        filePath: filePath,
        totalChapters: chapters.length,
      );

      return EpubResult(book: ebook, chapters: chapters);
    } catch (e) {
      throw Exception('Failed to parse MOBI/AZW3: $e');
    }
  }

  String? _extractTitle(String html) {
    final titleMatch = RegExp(r'<title>([\s\S]*?)</title>', caseSensitive: false)
        .firstMatch(html);
    if (titleMatch != null) {
      return titleMatch.group(1)?.trim();
    }
    final hMatch = RegExp(r'<h[1-6][^>]*>([\s\S]*?)</h[1-6]>', caseSensitive: false)
        .firstMatch(html);
    if (hMatch != null) {
      return hMatch.group(1)?.trim();
    }
    return null;
  }
}
