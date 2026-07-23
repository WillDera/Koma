import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kindle_unpack/kindle_unpack.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'epub_service.dart';

class _RawPart {
  final Uint8List bytes;
  final int index;
  _RawPart(this.bytes, this.index);
}

class _MobiRaw {
  final String title;
  final String? author;
  final Uint8List? coverBytes;
  final String? coverExtension;
  final List<_RawPart> parts;
  _MobiRaw({
    required this.title,
    this.author,
    this.coverBytes,
    this.coverExtension,
    required this.parts,
  });
}

Future<_MobiRaw> _parseMobiIsolate(Uint8List bytes) async {
  final book = KindleBook.fromBytes(bytes);

  String? author;
  try {
    final exth = book.exth;
    if (exth != null && exth.authors.isNotEmpty) {
      author = exth.authors.join(', ');
    }
  } catch (_) {}

  Uint8List? coverBytes;
  String? coverExtension;
  try {
    final coverImg = book.images.cover;
    if (coverImg != null) {
      coverBytes = Uint8List.fromList(coverImg.data);
      coverExtension = coverImg.format.extension;
    }
  } catch (_) {}

  final parts = <_RawPart>[];
  if (book.parts.isNotEmpty) {
    for (var i = 0; i < book.parts.length; i++) {
      parts.add(_RawPart(Uint8List.fromList(book.parts[i].bytes), i));
    }
  } else {
    parts.add(_RawPart(Uint8List.fromList(book.rawML), 0));
  }

  return _MobiRaw(
    title: book.title,
    author: author,
    coverBytes: coverBytes,
    coverExtension: coverExtension,
    parts: parts,
  );
}

class MobiService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final raw = await compute(_parseMobiIsolate, Uint8List.fromList(bytes));
      final bookIdFinal = bookId ?? 0;

      // Save cover image (main isolate for path_provider)
      String? coverPath;
      if (raw.coverBytes != null && raw.coverExtension != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final coverDir = Directory('${appDir.path}/covers');
          if (!await coverDir.exists()) await coverDir.create(recursive: true);
          final outFile = File(
            '${coverDir.path}/${DateTime.now().millisecondsSinceEpoch}.${raw.coverExtension}',
          );
          await outFile.writeAsBytes(raw.coverBytes!);
          coverPath = outFile.path;
        } catch (_) {}
      }

      // Chapters from parts
      final chapters = <Chapter>[];
      if (raw.parts.isNotEmpty) {
        for (final part in raw.parts) {
          final html = String.fromCharCodes(part.bytes);
          final chTitle = _extractTitle(html) ?? 'Chapter ${part.index + 1}';
          chapters.add(
            Chapter(
              id: 0,
              bookId: bookIdFinal,
              title: chTitle,
              content: html,
              index: part.index,
            ),
          );
        }
      }

      final ebook = Book(
        id: bookIdFinal,
        title: raw.title,
        author: raw.author,
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
    final titleMatch = RegExp(
      r'<title>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      return titleMatch.group(1)?.trim();
    }
    final hMatch = RegExp(
      r'<h[1-6][^>]*>([\s\S]*?)</h[1-6]>',
      caseSensitive: false,
    ).firstMatch(html);
    if (hMatch != null) {
      return hMatch.group(1)?.trim();
    }
    return null;
  }
}
