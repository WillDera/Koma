import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/reader/html/kir_model.dart';
import '../../features/reader/layout/kre_layout.dart';
import '../../features/reader/scene/scene_chrome.dart';
import '../../src/rust/api/koma.dart' as kre;

class KomaChapterPayload {
  const KomaChapterPayload({required this.chapter, this.scene});

  final KirChapter chapter;
  final SceneChrome? scene;
}

/// On-disk `.koma` cache: `{documents}/koma/{bookId}.koma`.
///
/// Compile is best-effort: import still succeeds if KRE fails. Existing
/// library books without a package stay on [HtmlToDocument].
class KomaPackageStore {
  KomaPackageStore._();

  static const _rootName = 'koma';

  static Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_rootName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> fileFor(int bookId) async {
    final root = await _root();
    return File('${root.path}/$bookId.koma');
  }

  static Future<bool> existsFor(int bookId) async {
    return (await fileFor(bookId)).exists();
  }

  /// Compile [epubPath] to a cached package. Returns false on any failure.
  static Future<bool> compileEpub({
    required int bookId,
    required String epubPath,
  }) async {
    try {
      final bytes = await kre.compileEpub(path: epubPath);
      final file = await fileFor(bookId);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (e, st) {
      debugPrint('KomaPackageStore.compileEpub: $e\n$st');
      return false;
    }
  }

  static Future<void> deleteFor(int bookId) async {
    try {
      final file = await fileFor(bookId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Manifest chapter count, or null if the file is missing/unreadable.
  static Future<int?> chapterCount(int bookId) async {
    try {
      final file = await fileFor(bookId);
      if (!await file.exists()) return null;
      final infos = await kre.packageChapters(komaPath: file.path);
      return infos.length;
    } catch (_) {
      return null;
    }
  }

  static Future<KomaChapterPayload?> chapterByIndex({
    required int bookId,
    required int index,
  }) async {
    try {
      final file = await fileFor(bookId);
      if (!await file.exists()) return null;
      final dto = await kre.chapterPayloadByIndex(
        komaPath: file.path,
        index: index,
      );
      return KomaChapterPayload(
        chapter: _fromDto(dto.chapter),
        scene: dto.scene == null ? null : _sceneFromDto(dto.scene!),
      );
    } catch (e, st) {
      debugPrint('KomaPackageStore.chapterByIndex: $e\n$st');
      return null;
    }
  }

  /// Page-sized glyph boxes for [index]. Null if the package is missing.
  static Future<LayoutResult?> layoutPages({
    required int bookId,
    required int index,
    required int width,
    required int height,
    required double fontSize,
    required double lineHeight,
    double margin = 48,
  }) async {
    try {
      final file = await fileFor(bookId);
      if (!await file.exists()) return null;
      final dto = await kre.layoutChapterPages(
        komaPath: file.path,
        index: index,
        width: width,
        height: height,
        fontSize: fontSize,
        lineHeight: lineHeight,
        margin: margin,
      );
      return _layoutFromDto(dto);
    } catch (e, st) {
      debugPrint('KomaPackageStore.layoutPages: $e\n$st');
      return null;
    }
  }

  static LayoutResult _layoutFromDto(kre.LayoutResultDto dto) {
    return LayoutResult(
      plainText: dto.plainText,
      pages: [
        for (final p in dto.pages)
          LayoutPage(
            charStart: p.charStart,
            charEnd: p.charEnd,
            lines: [
              for (final l in p.lines)
                LayoutLine(
                  y: l.y,
                  height: l.height,
                  charStart: l.charStart,
                  charEnd: l.charEnd,
                  glyphs: [
                    for (final g in l.glyphs)
                      LayoutGlyph(
                        x: g.x,
                        y: g.y,
                        width: g.width,
                        height: g.height,
                        charStart: g.charStart,
                        charEnd: g.charEnd,
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  static SceneChrome _sceneFromDto(kre.SceneChromeDto s) {
    final ms = (s.fadeSeconds * 1000).round().clamp(0, 5000);
    return SceneChrome(
      environmentKind: s.environmentKind,
      background: SceneChrome.tryParseHex(s.backgroundHex),
      ambient: SceneChrome.tryParseHex(s.ambientHex),
      ambientIntensity: s.ambientIntensity,
      frost: s.frost,
      fade: Duration(milliseconds: ms),
    );
  }

  static KirChapter _fromDto(kre.KirChapterDto dto) {
    return KirChapter(
      id: dto.id,
      title: dto.title,
      blocks: dto.blocks.map(_blockFromDto).toList(growable: false),
    );
  }

  static KirBlock _blockFromDto(kre.KirBlockDto b) {
    return KirBlock(
      kind: b.kind,
      spans: [
        for (final s in b.spans)
          KirSpan(
            text: s.text,
            bold: s.bold,
            italic: s.italic,
            underline: s.underline,
            color: s.color,
          ),
      ],
      mediaId: b.mediaId,
      alt: b.alt,
      ordered: b.ordered,
      children: b.children.map(_blockFromDto).toList(growable: false),
    );
  }
}
