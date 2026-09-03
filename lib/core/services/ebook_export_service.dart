import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/book.dart';
import 'android_storage_access.dart';

/// Result of copying ebook source files to a user-chosen folder.
class EbookExportResult {
  const EbookExportResult({
    required this.exported,
    required this.skipped,
    required this.failed,
  });

  final int exported;
  final int skipped;
  final int failed;

  bool get isEmpty => exported == 0 && skipped == 0 && failed == 0;
}

/// Copies local ebook files out of the library into a destination directory.
class EbookExportService {
  EbookExportService._();

  /// Copies each [books] entry that has an existing [Book.filePath].
  ///
  /// Books without a file, or whose file is missing on disk, count as
  /// [EbookExportResult.skipped]. Copy failures count as
  /// [EbookExportResult.failed].
  static Future<EbookExportResult> exportToDirectory({
    required List<Book> books,
    required String destinationDir,
  }) async {
    final dest = Directory(destinationDir);
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }

    var exported = 0;
    var skipped = 0;
    var failed = 0;
    final usedNames = <String>{};

    // Seed with names already present so we do not overwrite existing files.
    await for (final entity in dest.list(followLinks: false)) {
      if (entity is File) {
        usedNames.add(p.basename(entity.path).toLowerCase());
      }
    }

    for (final book in books) {
      final srcPath = book.filePath?.trim();
      if (srcPath == null || srcPath.isEmpty) {
        skipped++;
        continue;
      }
      final src = File(srcPath);
      if (!await src.exists()) {
        skipped++;
        continue;
      }

      try {
        final fileName = _uniqueName(
          preferred: _preferredFileName(book, srcPath),
          used: usedNames,
        );
        usedNames.add(fileName.toLowerCase());
        final destPath = p.join(dest.path, fileName);
        if (AndroidStorageAccess.needsAllFilesAccess(destPath)) {
          await AndroidStorageAccess.copyFile(srcPath, destPath);
        } else {
          await src.copy(destPath);
        }
        exported++;
      } catch (_) {
        failed++;
      }
    }

    return EbookExportResult(
      exported: exported,
      skipped: skipped,
      failed: failed,
    );
  }

  static String _preferredFileName(Book book, String srcPath) {
    final original = p.basename(srcPath).trim();
    if (original.isNotEmpty && original != '.' && original != '..') {
      return original;
    }
    final ext = book.fileExtension.replaceFirst('.', '').trim();
    final base = _sanitizeBase(book.title);
    if (ext.isEmpty) return base;
    return '$base.$ext';
  }

  static String _sanitizeBase(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    return cleaned.isEmpty ? 'ebook' : cleaned;
  }

  static String _uniqueName({
    required String preferred,
    required Set<String> used,
  }) {
    if (!used.contains(preferred.toLowerCase())) return preferred;
    final stem = p.basenameWithoutExtension(preferred);
    final ext = p.extension(preferred);
    for (var i = 1; i < 10000; i++) {
      final candidate = '$stem ($i)$ext';
      if (!used.contains(candidate.toLowerCase())) return candidate;
    }
    return '$stem-${DateTime.now().millisecondsSinceEpoch}$ext';
  }
}
