import 'dart:io';

import 'package:epub_pro/epub_pro.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:image/image.dart' as img;
import 'app_storage.dart';
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

      final title = epubBook.title ?? 'Unknown Title';
      String? author;
      if (epubBook.authors.isNotEmpty) {
        author = epubBook.authors.first;
      } else if (epubBook.author != null && epubBook.author!.isNotEmpty) {
        author = epubBook.author;
      }

      // Extract cover image
      String? coverPath;
      try {
        final coverImage = epubBook.coverImage;
        if (coverImage != null) {
          final appDir = await AppStorage.documents();
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
      // Use both content.images and allFiles: epub_pro only classifies a
      // narrow MIME set as images (misses image/jpg, image/webp, etc.).
      final imagePaths = <String, String>{};
      await _collectImages(
        sessionId: sessionId,
        imagePaths: imagePaths,
        epubBook: epubBook,
      );

      final chapters = <Chapter>[];

      _extractChapters(
        epubBook.chapters,
        bookIdFinal,
        chapters,
        0,
        imagePaths,
      );

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

  Future<void> _collectImages({
    required String sessionId,
    required Map<String, String> imagePaths,
    required EpubBook epubBook,
  }) async {
    final content = epubBook.content;
    if (content == null) return;

    Future<void> store(String key, List<int>? bytes, {String? mime}) async {
      if (bytes == null || bytes.isEmpty) return;
      if (!EbookMediaStore.looksLikeImage(href: key, mime: mime)) return;
      final path = await EbookMediaStore.storeBytes(
        bookOrSessionId: sessionId,
        bytes: bytes,
        logicalName: key,
      );
      EbookMediaStore.indexImagePath(
        imagePaths,
        logicalKey: key,
        path: path,
      );
    }

    for (final entry in content.images.entries) {
      await store(
        entry.key,
        entry.value.content,
        mime: entry.value.contentMimeType,
      );
    }

    for (final entry in content.allFiles.entries) {
      if (imagePaths.containsKey(entry.key)) continue;
      final file = entry.value;
      if (file is! EpubByteContentFile) continue;
      await store(
        entry.key,
        file.content,
        mime: file.contentMimeType,
      );
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
      final chTitle = ec.title ?? 'Chapter ${idx + 1}';
      String content = ec.htmlContent ?? '';
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
        final baseHref = ec.contentFileName;
        content = EbookMediaStore.rewriteImgSrcs(content, (src) {
          final key = EbookMediaStore.matchContentKey(
            src,
            imagePaths.keys,
            baseHref: baseHref,
          );
          if (key == null) {
            if (kDebugMode &&
                !src.startsWith('http://') &&
                !src.startsWith('https://')) {
              debugPrint(
                'EpubService: unresolved image src="$src" '
                '(chapter=${baseHref ?? "?"})',
              );
            }
            return null;
          }
          return imagePaths[key];
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
      if (ec.subChapters.isNotEmpty) {
        idx = _extractChapters(
          ec.subChapters,
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
