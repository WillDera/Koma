import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_storage.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'ebook_media_store.dart';
import 'epub_service.dart';
import 'kindle_book_adapter.dart';

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
  final List<({String name, Uint8List data, String ext})> images;
  _MobiRaw({
    required this.title,
    this.author,
    this.coverBytes,
    this.coverExtension,
    required this.parts,
    required this.images,
  });
}

Future<_MobiRaw> _parseMobiIsolate(Uint8List bytes) async {
  final book = KindleBookAdapter.fromBytes(bytes);

  String? author;
  try {
    final exth = book.section.exth;
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

  final images = <({String name, Uint8List data, String ext})>[];
  try {
    for (final img in book.images.all) {
      images.add((
        name: img.name,
        data: Uint8List.fromList(img.data),
        ext: img.format.extension,
      ));
    }
  } catch (_) {}

  return _MobiRaw(
    title: book.title,
    author: author,
    coverBytes: coverBytes,
    coverExtension: coverExtension,
    parts: parts,
    images: images,
  );
}

class MobiService {
  Future<EpubResult?> parse(String filePath, {int? bookId}) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final raw = await compute(_parseMobiIsolate, Uint8List.fromList(bytes));
      final bookIdFinal = bookId ?? 0;
      final sessionId = bookId != null && bookId > 0
          ? '$bookId'
          : EbookMediaStore.newSessionId();

      // Save cover image (main isolate for path_provider)
      String? coverPath;
      if (raw.coverBytes != null && raw.coverExtension != null) {
        try {
          final appDir = await AppStorage.documents();
          final coverDir = Directory('${appDir.path}/covers');
          if (!await coverDir.exists()) await coverDir.create(recursive: true);
          final outFile = File(
            '${coverDir.path}/${DateTime.now().millisecondsSinceEpoch}.${raw.coverExtension}',
          );
          await outFile.writeAsBytes(raw.coverBytes!);
          coverPath = outFile.path;
        } catch (_) {}
      }

      final imagePaths = <String, String>{};
      for (final img in raw.images) {
        final path = await EbookMediaStore.storeBytes(
          bookOrSessionId: sessionId,
          bytes: img.data,
          preferredExt: img.ext,
          logicalName: img.name,
        );
        imagePaths[img.name] = path;
        // Also index by basename without path for recindex-style refs.
        final base = img.name.split('/').last;
        imagePaths.putIfAbsent(base, () => path);
      }

      // Chapters from parts
      final chapters = <Chapter>[];
      if (raw.parts.isNotEmpty) {
        for (final part in raw.parts) {
          var html = String.fromCharCodes(part.bytes);
          final chTitle = _extractTitle(html) ?? 'Chapter ${part.index + 1}';
          if (imagePaths.isNotEmpty) {
            html = EbookMediaStore.rewriteImgSrcs(html, (src) {
              final key = EbookMediaStore.matchContentKey(src, imagePaths.keys);
              return key == null ? null : imagePaths[key];
            });
            // Kindle often uses recindex="N" without a normal src — promote
            // to img src when we can map N → imageNNNNN.
            html = html.replaceAllMapped(
              RegExp(
                r'''<img\b([^>]*?)\brecindex\s*=\s*["']?(\d+)["']?([^>]*)>''',
                caseSensitive: false,
              ),
              (m) {
                final idx = int.tryParse(m.group(2) ?? '') ?? -1;
                if (idx < 0) return m.group(0)!;
                final name =
                    'image${idx.toString().padLeft(5, '0')}.jpg';
                final altNames = [
                  name,
                  'image${idx.toString().padLeft(5, '0')}.png',
                  'image${idx.toString().padLeft(5, '0')}.gif',
                ];
                String? path;
                for (final n in altNames) {
                  path = imagePaths[n];
                  if (path != null) break;
                }
                // Fallback: Nth image in enumeration order.
                if (path == null && idx < raw.images.length) {
                  path = imagePaths[raw.images[idx].name];
                }
                if (path == null) return m.group(0)!;
                final uri = Uri.file(path).toString();
                return '<img src="$uri"${m.group(1) ?? ''}${m.group(3) ?? ''}>';
              },
            );
          }
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

      return EpubResult(
        book: ebook,
        chapters: chapters,
        mediaSessionId: sessionId,
      );
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
