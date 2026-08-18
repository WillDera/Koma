import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_font.dart';

/// Stores and registers user-imported TTF/OTF fonts for UI and reading.
class CustomFontService {
  CustomFontService._();
  static final CustomFontService instance = CustomFontService._();

  static const _manifestName = 'fonts.json';
  static const _familyPrefix = 'KomaFont_';
  static const _uuid = Uuid();

  final Set<String> _loadedFamilies = {};

  Future<Directory> _fontsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'fonts'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _manifestFile() async {
    final root = await _fontsRoot();
    return File(p.join(root.path, _manifestName));
  }

  Future<List<CustomFont>> listFonts() async {
    final file = await _manifestFile();
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final raw = json['fonts'] as List<dynamic>? ?? [];
      return raw
          .map((e) => CustomFont.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((f) => f.id.isNotEmpty && f.faces.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeManifest(List<CustomFont> fonts) async {
    final file = await _manifestFile();
    await file.writeAsString(
      jsonEncode({'fonts': fonts.map((f) => f.toJson()).toList()}),
    );
  }

  /// Registers font bytes with Flutter. Safe to call repeatedly for the same family.
  Future<void> ensureLoaded(CustomFont font) async {
    if (_loadedFamilies.contains(font.registeredFamily)) return;
    final root = await _fontsRoot();
    final fontDir = Directory(p.join(root.path, font.id));
    final loader = FontLoader(font.registeredFamily);
    for (final face in font.faces) {
      final file = File(p.join(fontDir.path, face.relativePath));
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      loader.addFont(
        Future<ByteData>.value(
          ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      );
    }
    await loader.load();
    _loadedFamilies.add(font.registeredFamily);
  }

  Future<void> ensureLoadedById(String id, List<CustomFont> catalog) async {
    for (final font in catalog) {
      if (font.id == id) {
        await ensureLoaded(font);
        return;
      }
    }
  }

  /// Import one or more font files as a single family (e.g. Regular + Bold).
  Future<CustomFont?> importFiles(List<File> sources) async {
    final valid = sources
        .where((f) => f.existsSync() && _isFontExtension(f.path))
        .toList();
    if (valid.isEmpty) return null;

    final id = _uuid.v4();
    final registeredFamily = '$_familyPrefix$id';
    final root = await _fontsRoot();
    final fontDir = Directory(p.join(root.path, id));
    await fontDir.create(recursive: true);

    final faces = <CustomFontFace>[];
    for (final source in valid) {
      final basename = p.basename(source.path);
      final dest = File(p.join(fontDir.path, basename));
      await source.copy(dest.path);
      faces.add(
        CustomFontFace(
          relativePath: basename,
          weight: _inferWeight(basename),
        ),
      );
    }

    final displayName = _displayNameFromFile(valid.first.path);
    final font = CustomFont(
      id: id,
      displayName: displayName,
      registeredFamily: registeredFamily,
      faces: faces,
    );

    final catalog = await listFonts();
    catalog.add(font);
    await _writeManifest(catalog);
    await ensureLoaded(font);
    return font;
  }

  /// Absolute path of a face file, preferring [weight] (400 = regular).
  Future<String?> facePath(CustomFont font, {int weight = 400}) async {
    final root = await _fontsRoot();
    CustomFontFace? face;
    for (final f in font.faces) {
      if (f.weight == weight) {
        face = f;
        break;
      }
    }
    face ??= font.faces.isEmpty ? null : font.faces.first;
    if (face == null) return null;
    final file = File(p.join(root.path, font.id, face.relativePath));
    return file.existsSync() ? file.path : null;
  }

  Future<void> deleteFont(String id) async {
    final catalog = await listFonts();
    for (final font in catalog) {
      if (font.id == id) {
        _loadedFamilies.remove(font.registeredFamily);
        break;
      }
    }
    final root = await _fontsRoot();
    final fontDir = Directory(p.join(root.path, id));
    if (fontDir.existsSync()) {
      await fontDir.delete(recursive: true);
    }
    catalog.removeWhere((f) => f.id == id);
    await _writeManifest(catalog);
  }

  static bool _isFontExtension(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.ttf' || ext == '.otf';
  }

  static int _inferWeight(String filename) {
    final name = p.basenameWithoutExtension(filename).toLowerCase();
    if (name.contains('black') || name.contains('-blk')) return 900;
    if (name.contains('extrabold') || name.contains('ultrabold')) return 800;
    if (name.contains('bold') || name.contains('-bd') || name.endsWith('b')) {
      return 700;
    }
    if (name.contains('semibold') || name.contains('demibold')) return 600;
    if (name.contains('medium') || name.contains('-med')) return 500;
    if (name.contains('light') || name.contains('-lt')) return 300;
    if (name.contains('thin') || name.contains('extralight')) return 200;
    return 400;
  }

  static String _displayNameFromFile(String path) {
    var name = p.basenameWithoutExtension(path);
    name = name.replaceAll(RegExp(r'[-_]?(regular|bold|light|medium|thin|black|semibold|italic)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (name.isEmpty) return 'Custom font';
    return name;
  }
}
