import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:koni_archive/io.dart';
import 'package:path/path.dart' as p;

import 'app_storage.dart';
import 'local_cbz_source.dart';

/// Resolves manga page image paths for local CBZ / folder chapters.
class LocalCbzPages {
  LocalCbzPages._();

  /// Returns absolute paths to page images for [chapterPath].
  ///
  /// Archives are extracted once under the app cache; folders of images are
  /// listed in place. Returns an empty list when nothing readable is found.
  static Future<List<String>> resolvePages(String chapterPath) async {
    final trimmed = chapterPath.trim();
    if (trimmed.isEmpty) return const [];

    final entityType = await FileSystemEntity.type(trimmed);
    if (entityType == FileSystemEntityType.directory) {
      return _listImageFolder(trimmed);
    }
    if (entityType != FileSystemEntityType.file) return const [];
    if (!LocalCbzSource.isArchivePath(trimmed)) return const [];
    return _extractArchive(trimmed);
  }

  static Future<List<String>> _listImageFolder(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (LocalCbzSource.isImagePath(entity.path) &&
          !_isCoverFile(p.basename(entity.path))) {
        files.add(entity);
      }
    }
    files.sort((a, b) => _naturalCompare(p.basename(a.path), p.basename(b.path)));
    return [for (final f in files) f.path];
  }

  static Future<List<String>> _extractArchive(String archivePath) async {
    final cacheRoot = await AppStorage.cache();
    final key =
        sha256.convert(utf8.encode(archivePath)).toString().substring(0, 20);
    final outDir = Directory(p.join(cacheRoot.path, 'local_cbz', key));
    final marker = File(p.join(outDir.path, '.ready'));

    if (await marker.exists()) {
      final cached = await _listExtracted(outDir);
      if (cached.isNotEmpty) return cached;
    }

    if (await outDir.exists()) {
      await outDir.delete(recursive: true);
    }
    await outDir.create(recursive: true);

    final archive = await openArchiveFile(archivePath);
    try {
      final byPath = <String, ArchiveEntry>{};
      for (final ext in ['png', 'jpg', 'jpeg', 'webp', 'gif', 'avif']) {
        for (final e in archive.glob('**.$ext')) {
          if (!e.isFile) continue;
          if (_isCoverFile(p.basename(e.path))) continue;
          byPath[e.path] = e;
        }
      }
      final pages = byPath.values.toList()
        ..sort((a, b) => _naturalCompare(a.path, b.path));

      for (var i = 0; i < pages.length; i++) {
        final entry = pages[i];
        final ext = p.extension(entry.path).toLowerCase();
        final safeExt = LocalCbzSource.imageExtensions.contains(ext)
            ? ext
            : '.jpg';
        final out = File(
          p.join(outDir.path, '${i.toString().padLeft(4, '0')}$safeExt'),
        );
        final sink = out.openWrite();
        try {
          await sink.addStream(archive.openRead(entry));
        } finally {
          await sink.close();
        }
      }
      await marker.writeAsString('${pages.length}');
    } finally {
      await archive.close();
    }

    return _listExtracted(outDir);
  }

  static Future<List<String>> _listExtracted(Directory outDir) async {
    if (!await outDir.exists()) return const [];
    final files = <File>[];
    await for (final entity in outDir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (p.basename(entity.path).startsWith('.')) continue;
      if (LocalCbzSource.isImagePath(entity.path)) files.add(entity);
    }
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return [for (final f in files) f.path];
  }

  static bool _isCoverFile(String name) =>
      LocalCbzSource.coverNames.contains(name.toLowerCase());

}

/// Natural-ish path compare: splits digit runs so `page2` < `page10`.
int _naturalCompare(String a, String b) {
  final ra = _naturalParts(a.toLowerCase());
  final rb = _naturalParts(b.toLowerCase());
  final n = ra.length < rb.length ? ra.length : rb.length;
  for (var i = 0; i < n; i++) {
    final pa = ra[i];
    final pb = rb[i];
    if (pa is int && pb is int) {
      final c = pa.compareTo(pb);
      if (c != 0) return c;
    } else {
      final c = '$pa'.compareTo('$pb');
      if (c != 0) return c;
    }
  }
  return ra.length.compareTo(rb.length);
}

List<Object> _naturalParts(String s) {
  final parts = <Object>[];
  final buf = StringBuffer();
  var inDigit = false;
  for (final code in s.codeUnits) {
    final digit = code >= 48 && code <= 57;
    if (buf.isEmpty) {
      inDigit = digit;
      buf.writeCharCode(code);
      continue;
    }
    if (digit == inDigit) {
      buf.writeCharCode(code);
    } else {
      parts.add(inDigit ? int.parse(buf.toString()) : buf.toString());
      buf.clear();
      inDigit = digit;
      buf.writeCharCode(code);
    }
  }
  if (buf.isNotEmpty) {
    parts.add(inDigit ? int.parse(buf.toString()) : buf.toString());
  }
  return parts;
}
