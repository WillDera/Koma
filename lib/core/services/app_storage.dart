import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'android_storage_access.dart';

/// Paths before/after [AppStorage.migrateAndSetRoot] when files actually moved.
/// Callers rewrite Isar absolute paths with [StoragePathRewrite.afterMigrate].
class StorageMigrateResult {
  const StorageMigrateResult({
    required this.oldDocuments,
    required this.oldSupport,
    required this.newDocuments,
    required this.newSupport,
  });

  final String oldDocuments;
  final String oldSupport;
  final String newDocuments;
  final String newSupport;
}

class _StorageLayout {
  const _StorageLayout({
    required this.documents,
    required this.support,
    required this.cache,
    required this.unified,
  });

  final String documents;
  final String support;
  final String cache;
  final bool unified;

  bool sameAs(_StorageLayout other) =>
      _canon(documents) == _canon(other.documents) &&
      _canon(support) == _canon(other.support) &&
      _canon(cache) == _canon(other.cache);
}

String _canon(String path) => p.normalize(Directory(path).absolute.path);

/// App-wide data root. When the user picks a folder, every Koma-created
/// file (Isar, downloads, covers, exports, fonts, Piper voices, …) lives
/// under that folder. Changing the folder moves existing data there.
///
/// When no folder is set, paths match the historical split:
/// documents vs support directories from path_provider.
class AppStorage {
  AppStorage._();

  static const prefsKey = 'storage_root_path';

  static String? _root;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(prefsKey);
      _root = (stored == null || stored.isEmpty) ? null : stored;
    } catch (_) {
      _root = null;
    }
    _ready = true;
  }

  static bool get usesCustomRoot => _root != null && _root!.isNotEmpty;

  static String? get rootPath => _root;

  /// Persists [path] as the data root and **moves** all Koma data from the
  /// previous location. Pass `null` to return to the app-default dirs.
  ///
  /// Close Isar (and pause downloads) before calling this so database files
  /// are not locked.
  ///
  /// Returns [StorageMigrateResult] when files moved so the caller can rewrite
  /// absolute paths stored in Isar (ebook covers, chapter media, …).
  static Future<StorageMigrateResult?> migrateAndSetRoot(String? path) async {
    await init();
    final from = await _layoutFor(_root);
    final trimmed = path?.trim();
    final nextRoot = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final to = await _layoutFor(nextRoot);
    final moved = !from.sameAs(to);
    if (moved) {
      _assertNotNested(from, to);
      if (to.unified) {
        await Directory(to.documents).create(recursive: true);
      } else {
        await Directory(to.documents).create(recursive: true);
        await Directory(to.support).create(recursive: true);
        await Directory(to.cache).create(recursive: true);
      }
      await _migrate(from, to);
    }
    final prefs = await SharedPreferences.getInstance();
    if (nextRoot == null) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, nextRoot);
    }
    _root = nextRoot;
    if (!moved) return null;
    return StorageMigrateResult(
      oldDocuments: from.documents,
      oldSupport: from.support,
      newDocuments: to.documents,
      newSupport: to.support,
    );
  }

  static Future<void> setRootPath(String? path) async {
    await migrateAndSetRoot(path);
  }

  static Future<Directory> documents() async {
    await init();
    if (usesCustomRoot) return _ensureRoot();
    return getApplicationDocumentsDirectory();
  }

  static Future<Directory> support() async {
    await init();
    if (usesCustomRoot) return _ensureRoot();
    return getApplicationSupportDirectory();
  }

  static Future<Directory> cache() async {
    await init();
    if (usesCustomRoot) {
      final dir = Directory('${_root!}/cache');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return getApplicationCacheDirectory();
  }

  static Future<Directory> _ensureRoot() async {
    final dir = Directory(_root!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<_StorageLayout> _layoutFor(String? root) async {
    if (root != null && root.isNotEmpty) {
      return _StorageLayout(
        documents: root,
        support: root,
        cache: p.join(root, 'cache'),
        unified: true,
      );
    }
    return _StorageLayout(
      documents: (await getApplicationDocumentsDirectory()).path,
      support: (await getApplicationSupportDirectory()).path,
      cache: (await getApplicationCacheDirectory()).path,
      unified: false,
    );
  }

  static void _assertNotNested(_StorageLayout from, _StorageLayout to) {
    final sources = {_canon(from.documents), _canon(from.support), _canon(from.cache)};
    for (final dest in [_canon(to.documents), _canon(to.support), _canon(to.cache)]) {
      for (final src in sources) {
        if (dest != src && p.isWithin(src, dest)) {
          throw StateError(
            'Cannot move data into a folder inside the current data location.',
          );
        }
      }
    }
  }

  static Future<void> _migrate(_StorageLayout from, _StorageLayout to) async {
    if (from.unified && to.unified) {
      await _moveChildren(from.documents, to.documents);
      return;
    }
    if (from.unified && !to.unified) {
      await _moveChildren(from.cache, to.cache);
      await _splitUnifiedIntoDefault(from.documents, to);
      return;
    }
    // Default split → custom. Do not touch Flutter's app_flutter runtime
    // (flutter_assets/kernel_blob.bin is not copyable) or the system cache.
    await _moveChildren(from.documents, to.documents, komaOnly: true);
    if (_canon(from.support) != _canon(from.documents)) {
      await _moveChildren(from.support, to.support, komaOnly: true);
    }
  }

  /// Flutter / plugin trees that live next to our files in
  /// getApplicationDocumentsDirectory. Moving them to shared storage fails
  /// (EPERM on kernel_blob.bin) and would break the engine.
  static const _runtimeNames = {
    'flutter_assets',
    'res',
    'flutter_inappwebview',
  };

  /// Names Koma actually writes under documents/support.
  static const _komaDirNames = {
    'koma',
    'ebook_media',
    'piper_voices',
    'fonts',
    'covers',
    'thumbnails',
    'downloads',
    'benchmark',
    'exports',
    'updates',
    'extensions',
    'manga_covers',
    'manga',
    'cache',
  };

  static bool _skipName(String name) {
    if (name.startsWith('.')) return true;
    return _runtimeNames.contains(name);
  }

  static bool _isKomaArtifact(String name) {
    if (_komaDirNames.contains(name)) return true;
    if (name.startsWith('koma.isar')) return true;
    final ext = p.extension(name).toLowerCase();
    return ext == '.ttf' || ext == '.otf';
  }

  static const _supportFolderNames = {'extensions', 'manga_covers', 'manga'};

  /// Custom roots mix documents + support. Restore the historical split so
  /// downloads (`manga/`) and extensions keep working under path_provider.
  static Future<void> _splitUnifiedIntoDefault(
    String unifiedRoot,
    _StorageLayout to,
  ) async {
    for (final name in _supportFolderNames) {
      final src = Directory(p.join(unifiedRoot, name));
      if (await src.exists()) {
        await _moveInto(src, p.join(to.support, name));
      }
    }
    final root = Directory(unifiedRoot);
    if (await root.exists()) {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.ttf' || ext == '.otf') {
          await _moveInto(entity, p.join(to.support, p.basename(entity.path)));
        }
      }
    }
    await _moveChildren(
      unifiedRoot,
      to.documents,
      skipNames: const {'cache'},
      komaOnly: true,
    );
  }

  static Future<void> _moveChildren(
    String fromPath,
    String toPath, {
    Set<String> skipNames = const {},
    bool komaOnly = false,
  }) async {
    if (_canon(fromPath) == _canon(toPath)) return;
    final from = Directory(fromPath);
    if (!await from.exists()) return;
    final to = Directory(toPath);
    if (!await to.exists()) await to.create(recursive: true);

    await for (final entity in from.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == '.' || name == '..') continue;
      if (skipNames.contains(name) || _skipName(name)) continue;
      if (komaOnly && !_isKomaArtifact(name)) continue;
      await _moveInto(entity, p.join(to.path, name));
    }
  }

  static Future<void> _moveInto(FileSystemEntity src, String destPath) async {
    final destDir = Directory(destPath);
    final destFile = File(destPath);
    if (src is Directory) {
      if (await destFile.exists()) await destFile.delete();
      if (await destDir.exists()) {
        await _moveChildren(src.path, destPath);
        try {
          await src.delete(recursive: true);
        } catch (_) {}
        return;
      }
      await _relocate(src, destPath);
      return;
    }
    if (src is File) {
      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }
      if (await destFile.exists()) await destFile.delete();
      await _relocate(src, destPath);
    }
  }

  static Future<void> _relocate(FileSystemEntity src, String destPath) async {
    try {
      await src.rename(destPath);
      return;
    } on FileSystemException {
      // Cross-device (typical when leaving app-private storage).
    }
    if (src is Directory) {
      await _copyDirectory(src, Directory(destPath));
      await src.delete(recursive: true);
    } else if (src is File) {
      await _copyFile(src, destPath);
      await src.delete();
    }
  }

  static Future<void> _copyFile(File src, String destPath) async {
    try {
      await src.copy(destPath);
    } on FileSystemException {
      await AndroidStorageAccess.copyFile(src.path, destPath);
    }
  }

  static Future<void> _copyDirectory(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in src.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (_skipName(name)) continue;
      final next = p.join(dest.path, name);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(next));
      } else if (entity is File) {
        await _copyFile(entity, next);
      }
    }
  }
}
