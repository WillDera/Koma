import 'dart:io';

import 'package:path/path.dart' as p;

import '../../eval/dispatch_service.dart';
import '../services/app_storage.dart';
import '../services/extension_source_resolve.dart';
import '../repositories/repositories.dart';

/// Fetch + cache novel chapter HTML via extension `getHtmlContent`.
class NovelHtmlContentService {
  NovelHtmlContentService({
    required this._repos,
    required this._dispatch,
  });

  final Repositories _repos;
  final ExtensionDispatchService _dispatch;

  Future<Directory> _chapterDir({
    required String sourceId,
    required int mangaId,
    required String chapterUrl,
  }) async {
    final root = await AppStorage.documents();
    final safeChapter = chapterUrl.replaceAll(RegExp(r'[^\w.-]+'), '_');
    final dir = Directory(
      p.join(
        root.path,
        'novels',
        sourceId,
        '$mangaId',
        safeChapter,
      ),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _htmlFile({
    required String sourceId,
    required int mangaId,
    required String chapterUrl,
  }) async {
    final dir = await _chapterDir(
      sourceId: sourceId,
      mangaId: mangaId,
      chapterUrl: chapterUrl,
    );
    return File(p.join(dir.path, 'chapter.html'));
  }

  /// Returns cleaned HTML suitable for [TextExtractor] / the novel reader.
  Future<String> load({
    required String sourceId,
    required int mangaId,
    required String mangaName,
    required String chapterUrl,
    bool forceNetwork = false,
  }) async {
    final file = await _htmlFile(
      sourceId: sourceId,
      mangaId: mangaId,
      chapterUrl: chapterUrl,
    );
    if (!forceNetwork && await file.exists()) {
      final cached = await file.readAsString();
      if (cached.trim().isNotEmpty) return cached;
    }

    final source = await resolveExtensionMSource(_repos, sourceId);
    var html = await _dispatch.getHtmlContent(
      source,
      name: mangaName,
      url: chapterUrl,
    );
    html = html.trim();
    // Defensive: some hosts still wrap the string in JSON quotes.
    if (html.length >= 2 && html.startsWith('"') && html.endsWith('"')) {
      try {
        html = html.substring(1, html.length - 1);
        html = html
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\/', '/');
      } catch (_) {}
    }
    if (!html.contains('<html') && !html.contains('<body')) {
      html = await _dispatch.cleanHtmlContent(source, html);
    }
    await file.writeAsString(html);
    return html;
  }
}
