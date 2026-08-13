import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'ebook_media_store.dart';

class EpubResult {
  final Book book;
  final List<Chapter> chapters;

  /// Pending media folder key written during parse; promote via
  /// [EbookMediaStore.promote] after Isar assigns a real book id.
  final String? mediaSessionId;

  EpubResult({
    required this.book,
    required this.chapters,
    this.mediaSessionId,
  });
}

class EpubService {
  Future<EpubResult?> parseEpub(String filePath, {int? bookId}) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      final title = epubBook.Title ?? 'Unknown Title';
      String? author;
      if (epubBook.AuthorList != null && epubBook.AuthorList!.isNotEmpty) {
        author = epubBook.AuthorList!.first;
      }

      // Extract cover image
      String? coverPath;
      try {
        final coverImage = epubBook.CoverImage;
        if (coverImage != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final coverDir = Directory('${appDir.path}/covers');
          if (!await coverDir.exists()) {
            await coverDir.create(recursive: true);
          }
          final coverFile = File(
            '${coverDir.path}/${DateTime.now().millisecondsSinceEpoch}.png',
          );
          final pngBytes = img.encodePng(coverImage);
          await coverFile.writeAsBytes(pngBytes);
          coverPath = coverFile.path;
        }
      } catch (_) {
        // cover extraction is best-effort
      }

      final bookIdFinal = bookId ?? 0;
      final sessionId = bookId != null && bookId > 0
          ? '$bookId'
          : EbookMediaStore.newSessionId();

      // Map EPUB image file names → absolute local paths.
      final imagePaths = <String, String>{};
      final images = epubBook.Content?.Images;
      if (images != null) {
        for (final entry in images.entries) {
          final content = entry.value.Content;
          if (content == null || content.isEmpty) continue;
          final path = await EbookMediaStore.storeBytes(
            bookOrSessionId: sessionId,
            bytes: content,
            logicalName: entry.key,
          );
          imagePaths[entry.key] = path;
        }
      }

      final chapters = <Chapter>[];

      if (epubBook.Chapters != null) {
        _extractChapters(
          epubBook.Chapters!,
          bookIdFinal,
          chapters,
          0,
          imagePaths,
        );
      }

      // Sort by index
      chapters.sort((a, b) => a.index.compareTo(b.index));

      final book = Book(
        id: bookIdFinal,
        title: title,
        author: author,
        coverPath: coverPath,
        source: 'local',
        filePath: filePath,
        totalChapters: chapters.length,
      );

      return EpubResult(
        book: book,
        chapters: chapters,
        mediaSessionId: sessionId,
      );
    } catch (e) {
      throw Exception('Failed to parse EPUB: $e');
    }
  }

  int _extractChapters(
    List<EpubChapter> epubChapters,
    int bookId,
    List<Chapter> output,
    int startIndex,
    Map<String, String> imagePaths,
  ) {
    int idx = startIndex;
    for (final ec in epubChapters) {
      final chTitle = ec.Title ?? 'Chapter ${idx + 1}';
      String content = ec.HtmlContent ?? '';
      // Strip CSS/style blocks that leak from EPUB stylesheets
      content = content.replaceAll(
        RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
        '',
      );
      // Strip @page rules and other CSS that appears as text
      content = content.replaceAll(
        RegExp(r'@[a-z]+\s*\{[^}]*\}', dotAll: true, caseSensitive: false),
        '',
      );
      if (imagePaths.isNotEmpty) {
        content = EbookMediaStore.rewriteImgSrcs(content, (src) {
          final key = EbookMediaStore.matchContentKey(src, imagePaths.keys);
          return key == null ? null : imagePaths[key];
        });
      }
      output.add(
        Chapter(
          id: 0,
          bookId: bookId,
          title: chTitle,
          content: content,
          index: idx++,
        ),
      );
      // Process subchapters
      if (ec.SubChapters != null && ec.SubChapters!.isNotEmpty) {
        idx = _extractChapters(
          ec.SubChapters!,
          bookId,
          output,
          idx,
          imagePaths,
        );
      }
    }
    return idx;
  }
}
