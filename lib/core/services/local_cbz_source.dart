/// Synthetic manga source for on-disk CBZ / comic archives.
abstract final class LocalCbzSource {
  static const sourceId = 'local';
  static const displayName = 'Local';

  static bool isLocal(String? sourceId) =>
      sourceId != null && sourceId.trim() == LocalCbzSource.sourceId;

  static const archiveExtensions = {
    '.cbz',
    '.cbr',
    '.cb7',
    '.cbt',
    '.zip',
    '.rar',
    '.7z',
  };

  static const imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.avif',
  };

  static const coverNames = {
    'cover.jpg',
    'cover.jpeg',
    'cover.png',
    'cover.webp',
    'folder.jpg',
    'folder.jpeg',
    'folder.png',
    'folder.webp',
  };

  static bool isArchivePath(String path) {
    final lower = path.toLowerCase();
    return archiveExtensions.any(lower.endsWith);
  }

  static bool isImagePath(String path) {
    final lower = path.toLowerCase();
    return imageExtensions.any(lower.endsWith);
  }
}
