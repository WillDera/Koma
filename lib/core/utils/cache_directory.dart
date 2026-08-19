import 'dart:io';

import 'package:path/path.dart' as path;
import '../services/app_storage.dart';

/// LNStash-side mirror of mangayomi's [StorageProvider] cache-directory APIs.
///
/// mangayomi keeps the entire app storage layout behind [StorageProvider]
/// (downloads, torrents, tmp, mpv, extension_server, ...). LNStash only needs
/// the cover/page image cache part, so this file exposes just that — with the
/// same folder-name convention mangayomi uses (`cacheimagecover`,
/// `cacheimagemanga`, custom [imageCacheFolderName]) so disk layout matches
/// the upstream app exactly.
class CacheDirectory {
  CacheDirectory._();

  /// Returns the directory used to persist cached network images.
  ///
  /// Defaults to `<applicationCacheDirectory>/<imageCacheFolderName ?? "cacheimagecover">`.
  /// This mirrors mangayomi's [StorageProvider.getCacheDirectory] precisely,
  /// including the default folder name.
  static Future<Directory> get(String? imageCacheFolderName) async {
    final dir = await AppStorage.cache();
    final cacheImagesDirectory = path.join(
      dir.path,
      imageCacheFolderName ?? 'cacheimagecover',
    );
    return Directory(cacheImagesDirectory);
  }

  /// Creates the cache directory (recursive) if it does not already exist and
  /// returns it. Mirrors mangayomi's [StorageProvider.createCacheDirectory].
  static Future<Directory> create(String? imageCacheFolderName) async {
    final dir = await get(imageCacheFolderName);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
